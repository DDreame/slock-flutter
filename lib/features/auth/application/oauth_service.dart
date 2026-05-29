import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';

/// Callback URL scheme used for the OAuth deep link.
const oAuthCallbackUrlScheme = 'slock';

/// Full callback URL passed to the OAuth provider's `returnTo` parameter.
const oAuthCallbackUrl = 'slock://oauth-callback';

/// Function signature matching `FlutterWebAuth2.authenticate`.
typedef BrowserLaunchFn = Future<String> Function({
  required String url,
  required String callbackUrlScheme,
});

/// Orchestrates the OAuth/SSO browser flow:
/// 1. Launch system browser → provider's consent screen
/// 2. Receive callback deep link with auth code
/// 3. Exchange code for tokens via POST /auth/{provider}/complete
abstract class OAuthService {
  /// Initiates the OAuth flow for [providerId].
  ///
  /// Returns the [AuthResult] (access + refresh tokens) on success.
  /// Throws [OAuthCancelledException] if the user cancels the flow.
  /// Throws [AppFailure] on network or exchange errors.
  Future<AuthResult> authenticate({required String providerId});
}

/// Exception thrown when the user cancels the OAuth browser flow.
class OAuthCancelledException implements Exception {
  const OAuthCancelledException();

  @override
  String toString() =>
      'OAuthCancelledException: User cancelled the OAuth flow.';
}

final oAuthServiceProvider = Provider<OAuthService>((ref) {
  final networkConfig = ref.watch(networkConfigProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return FlutterWebAuthOAuthService(
    baseUrl: networkConfig.baseUrl,
    authRepository: authRepo,
  );
});

/// Production OAuth service that launches the system browser via
/// `FlutterWebAuth2` and exchanges the returned code for tokens.
///
/// The [browserLaunch] parameter is injectable for testing — it defaults
/// to [FlutterWebAuth2.authenticate] in production.
class FlutterWebAuthOAuthService implements OAuthService {
  FlutterWebAuthOAuthService({
    required String baseUrl,
    required AuthRepository authRepository,
    BrowserLaunchFn? browserLaunch,
  })  : _baseUrl = baseUrl,
        _authRepository = authRepository,
        _browserLaunch = browserLaunch ?? FlutterWebAuth2.authenticate;

  final String _baseUrl;
  final AuthRepository _authRepository;
  final BrowserLaunchFn _browserLaunch;

  @override
  Future<AuthResult> authenticate({required String providerId}) async {
    final startUrl =
        '$_baseUrl/auth/$providerId/start?returnTo=$oAuthCallbackUrl';

    final String resultUrl;
    try {
      resultUrl = await _browserLaunch(
        url: startUrl,
        callbackUrlScheme: oAuthCallbackUrlScheme,
      );
    } on Exception catch (e) {
      // flutter_web_auth_2 throws PlatformException with code 'CANCELED'
      // when the user dismisses the browser.
      if (e.toString().contains('CANCELED') ||
          e.toString().contains('canceled') ||
          e.toString().contains('cancelled')) {
        throw const OAuthCancelledException();
      }
      rethrow;
    }

    final uri = Uri.parse(resultUrl);
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const SerializationFailure(
        message: 'OAuth callback missing authorization code.',
        causeType: 'OAuthCallbackError',
      );
    }

    // Exchange code for tokens.
    return _authRepository.completeOAuth(
      providerId: providerId,
      code: code,
    );
  }
}
