// =============================================================================
// B122 PR 3 — OAuth error handling + polish (load-bearing tests).
//
// Tests prove:
// 1. OAuthCancelledException → friendly oauthCancelledMessage shown (not silent).
// 2. ConflictFailure (409) → oauthConflictMessage (account linking guidance).
// 3. ForbiddenFailure (403) → oauthProviderDeniedMessage.
// 4. NetworkFailure → oauthNetworkErrorMessage.
// 5. TimeoutFailure → oauthNetworkErrorMessage.
// 6. AuthUser.hasPassword parsed from real _parseAuthUser path (repository).
// 7. L10n keys render correctly in ZH locale.
// 8. RegisterPage exercises same error classification as LoginPage.
//
// Reverting the error-specific handling → tests RED.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/application/oauth_service.dart';
import 'package:slock_app/features/auth/data/auth_provider.dart';
import 'package:slock_app/features/auth/data/auth_provider_repository.dart';
import 'package:slock_app/features/auth/data/auth_provider_repository_provider.dart';
import 'package:slock_app/features/auth/data/auth_repository.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/auth/presentation/page/login_page.dart';
import 'package:slock_app/features/auth/presentation/page/register_page.dart';
import 'package:slock_app/l10n/l10n.dart';

import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

// =============================================================================
// Tests
// =============================================================================

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Widget buildLoginPage(ProviderContainer container, {Locale? locale}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale ?? const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const LoginPage(),
      ),
    );
  }

  Widget buildRegisterPage(ProviderContainer container, {Locale? locale}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale ?? const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const RegisterPage(),
      ),
    );
  }

  ProviderContainer buildContainer({required OAuthService oauthService}) {
    return ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        authProviderRepositoryProvider.overrideWithValue(
          _FakeAuthProviderRepo([
            const AuthProvider(id: 'google', name: 'Google'),
          ]),
        ),
        oAuthServiceProvider.overrideWithValue(oauthService),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // OAuth cancel → friendly message
  // ---------------------------------------------------------------------------
  group('B122 PR 3 — OAuth cancel shows friendly message', () {
    testWidgets('OAuthCancelledException shows oauthCancelledMessage (EN)',
        (tester) async {
      final container = buildContainer(
        oauthService: _ThrowingOAuthService(const OAuthCancelledException()),
      );

      await tester.pumpWidget(buildLoginPage(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('oauth-provider-google')));
      await tester.pumpAndSettle();

      expect(
        find.text('Sign-in was cancelled.'),
        findsOneWidget,
        reason: 'Reverting cancel → friendly message to silent return → '
            'no message shown → RED.',
      );
    });

    testWidgets('OAuthCancelledException shows oauthCancelledMessage (ZH)',
        (tester) async {
      final container = buildContainer(
        oauthService: _ThrowingOAuthService(const OAuthCancelledException()),
      );

      await tester.pumpWidget(
        buildLoginPage(container, locale: const Locale('zh')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('oauth-provider-google')));
      await tester.pumpAndSettle();

      expect(
        find.text('登录已取消。'),
        findsOneWidget,
        reason: 'L10n: ZH cancel message must render.',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ConflictFailure (409) → account linking message
  // ---------------------------------------------------------------------------
  group('B122 PR 3 — OAuth conflict shows account linking message', () {
    testWidgets('ConflictFailure shows oauthConflictMessage', (tester) async {
      final container = buildContainer(
        oauthService: _ThrowingOAuthService(
          const ConflictFailure(message: 'email already exists'),
        ),
      );

      await tester.pumpWidget(buildLoginPage(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('oauth-provider-google')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This email is already registered. Please sign in with your password instead.',
        ),
        findsOneWidget,
        reason:
            'Reverting ConflictFailure handling → shows generic error → RED.',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ForbiddenFailure (403) → provider denied
  // ---------------------------------------------------------------------------
  group('B122 PR 3 — OAuth forbidden shows provider denied message', () {
    testWidgets('ForbiddenFailure shows oauthProviderDeniedMessage',
        (tester) async {
      final container = buildContainer(
        oauthService: _ThrowingOAuthService(
          const ForbiddenFailure(message: 'access denied'),
        ),
      );

      await tester.pumpWidget(buildLoginPage(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('oauth-provider-google')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Access was denied by the provider. Please try again or use a different sign-in method.',
        ),
        findsOneWidget,
        reason:
            'Reverting ForbiddenFailure handling → shows generic forbidden → RED.',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // NetworkFailure → network error message
  // ---------------------------------------------------------------------------
  group('B122 PR 3 — OAuth network failure shows network message', () {
    testWidgets('NetworkFailure shows oauthNetworkErrorMessage',
        (tester) async {
      final container = buildContainer(
        oauthService: _ThrowingOAuthService(
          const NetworkFailure(message: 'no internet'),
        ),
      );

      await tester.pumpWidget(buildLoginPage(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('oauth-provider-google')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not connect to the sign-in provider. Please check your connection and try again.',
        ),
        findsOneWidget,
        reason:
            'Reverting NetworkFailure handling → shows generic network → RED.',
      );
    });

    testWidgets('TimeoutFailure shows oauthNetworkErrorMessage',
        (tester) async {
      final container = buildContainer(
        oauthService: _ThrowingOAuthService(
          const TimeoutFailure(message: 'timed out'),
        ),
      );

      await tester.pumpWidget(buildLoginPage(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('oauth-provider-google')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not connect to the sign-in provider. Please check your connection and try again.',
        ),
        findsOneWidget,
        reason: 'TimeoutFailure must also show network error message.',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // AuthUser.hasPassword — real parse path through _ApiAuthRepository
  // ---------------------------------------------------------------------------
  group('B122 PR 3 — AuthUser.hasPassword via real parse path', () {
    test('hasPassword: true parsed from real repository getMe()', () async {
      final container = ProviderContainer(
        overrides: [
          appDioClientProvider.overrideWithValue(
            _FakeGetMeDioClient({'id': 'u1', 'name': 'A', 'hasPassword': true}),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(authRepositoryProvider);
      final user = await repo.getMe();
      expect(user.hasPassword, isTrue);
    });

    test('hasPassword: false parsed for OAuth-only accounts', () async {
      final container = ProviderContainer(
        overrides: [
          appDioClientProvider.overrideWithValue(
            _FakeGetMeDioClient(
              {'id': 'u2', 'name': 'B', 'hasPassword': false},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(authRepositoryProvider);
      final user = await repo.getMe();
      expect(user.hasPassword, isFalse);
    });

    test('hasPassword: null when server omits field', () async {
      final container = ProviderContainer(
        overrides: [
          appDioClientProvider.overrideWithValue(
            _FakeGetMeDioClient({'id': 'u3', 'name': 'C'}),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(authRepositoryProvider);
      final user = await repo.getMe();
      expect(user.hasPassword, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // RegisterPage — OAuth error handling (mirrors LoginPage tests)
  // ---------------------------------------------------------------------------
  group('B122 PR 3 — RegisterPage OAuth cancel shows friendly message', () {
    testWidgets('OAuthCancelledException shows oauthCancelledMessage',
        (tester) async {
      final container = buildContainer(
        oauthService: _ThrowingOAuthService(const OAuthCancelledException()),
      );

      await tester.pumpWidget(buildRegisterPage(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('oauth-provider-google')));
      await tester.pumpAndSettle();

      expect(
        find.text('Sign-in was cancelled.'),
        findsOneWidget,
        reason:
            'Reverting RegisterPage cancel handling → no message shown → RED.',
      );
    });
  });

  group('B122 PR 3 — RegisterPage OAuth conflict shows linking message', () {
    testWidgets('ConflictFailure shows oauthConflictMessage', (tester) async {
      final container = buildContainer(
        oauthService: _ThrowingOAuthService(
          const ConflictFailure(message: 'email already exists'),
        ),
      );

      await tester.pumpWidget(buildRegisterPage(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('oauth-provider-google')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This email is already registered. Please sign in with your password instead.',
        ),
        findsOneWidget,
        reason:
            'Reverting RegisterPage conflict handling → generic error → RED.',
      );
    });
  });

  group('B122 PR 3 — RegisterPage OAuth forbidden shows denied message', () {
    testWidgets('ForbiddenFailure shows oauthProviderDeniedMessage',
        (tester) async {
      final container = buildContainer(
        oauthService: _ThrowingOAuthService(
          const ForbiddenFailure(message: 'access denied'),
        ),
      );

      await tester.pumpWidget(buildRegisterPage(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('oauth-provider-google')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Access was denied by the provider. Please try again or use a different sign-in method.',
        ),
        findsOneWidget,
        reason:
            'Reverting RegisterPage forbidden handling → generic error → RED.',
      );
    });
  });

  group('B122 PR 3 — RegisterPage OAuth network shows connection message', () {
    testWidgets('NetworkFailure shows oauthNetworkErrorMessage',
        (tester) async {
      final container = buildContainer(
        oauthService: _ThrowingOAuthService(
          const NetworkFailure(message: 'no internet'),
        ),
      );

      await tester.pumpWidget(buildRegisterPage(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('oauth-provider-google')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not connect to the sign-in provider. Please check your connection and try again.',
        ),
        findsOneWidget,
        reason:
            'Reverting RegisterPage network handling → generic error → RED.',
      );
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

/// An OAuthService that throws a pre-configured error.
class _ThrowingOAuthService implements OAuthService {
  _ThrowingOAuthService(this._error);
  final Object _error;

  @override
  Future<AuthResult> authenticate({required String providerId}) async {
    // ignore: only_throw_errors
    throw _error;
  }
}

/// A fake [AppDioClient] that returns a canned response for GET /auth/me.
/// Exercises the real [_ApiAuthRepository._parseAuthUser] path.
class _FakeGetMeDioClient extends AppDioClient {
  _FakeGetMeDioClient(this._getMePayload) : super(Dio());
  final Map<String, dynamic> _getMePayload;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    return Response<T>(
      data: _getMePayload as T,
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> completeOAuth({
    required String providerId,
    required String code,
  }) async =>
      const AuthResult(accessToken: 'token', refreshToken: 'refresh');

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async =>
      const AuthResult(accessToken: 'token', refreshToken: 'refresh');

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  }) async =>
      const AuthResult(accessToken: 'token', refreshToken: 'refresh');

  @override
  Future<AuthUser> getMe() async =>
      const AuthUser(id: 'user-1', name: 'Test User', emailVerified: true);

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {}

  @override
  Future<void> verifyEmail({required String token}) async {}

  @override
  Future<void> resendVerification() async {}

  @override
  Future<void> logout({required String refreshToken}) async {}
}

class _FakeAuthProviderRepo implements AuthProviderRepository {
  _FakeAuthProviderRepo(this._providers);
  final List<AuthProvider> _providers;

  @override
  Future<List<AuthProvider>> getProviders() async => List.of(_providers);
}
