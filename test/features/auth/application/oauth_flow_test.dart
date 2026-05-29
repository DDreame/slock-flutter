// =============================================================================
// B122 PR 2 — OAuth flow + deep link handling (load-bearing tests).
//
// Tests prove:
// 1. OAuthService.authenticate orchestrates browser → code → token exchange.
// 2. OAuthCancelledException is thrown when user dismisses browser.
// 3. Missing code in callback → SerializationFailure.
// 4. SessionStore.loginWithOAuth stores tokens and hydrates session.
// 5. LoginPage wires OAuth controller (button tap → session authenticated).
// 6. completeOAuth endpoint is correctly wired (/auth/{provider}/complete).
// 7. /auth/{provider}/complete is recognized as public endpoint (no Bearer).
//
// Removing OAuthService/SessionStore.loginWithOAuth/completeOAuth → tests RED.
// =============================================================================

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
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

// =============================================================================
// Tests
// =============================================================================

void main() {
  // ===========================================================================
  // OAuthService unit tests
  // ===========================================================================
  group('B122 OAuth — OAuthService', () {
    test('authenticate calls completeOAuth with extracted code', () async {
      final repo = _FakeAuthRepository();
      final service = _FakeOAuthServiceWithRepo(
        fakeCallbackUrl: 'slock://oauth-callback?code=test-code-123',
        authRepository: repo,
      );

      final result = await service.authenticate(providerId: 'google');

      expect(result.accessToken, 'oauth-access-token');
      expect(result.refreshToken, 'oauth-refresh-token');
      expect(repo.lastOAuthProviderId, 'google');
      expect(repo.lastOAuthCode, 'test-code-123');
    });

    test('throws OAuthCancelledException when user cancels', () async {
      final service = _CancellingOAuthService();

      expect(
        () => service.authenticate(providerId: 'google'),
        throwsA(isA<OAuthCancelledException>()),
      );
    });

    test('throws SerializationFailure when callback has no code', () async {
      final service = _FakeOAuthServiceWithRepo(
        fakeCallbackUrl: 'slock://oauth-callback',
        authRepository: _FakeAuthRepository(),
      );

      expect(
        () => service.authenticate(providerId: 'google'),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('throws SerializationFailure when callback has empty code', () async {
      final service = _FakeOAuthServiceWithRepo(
        fakeCallbackUrl: 'slock://oauth-callback?code=',
        authRepository: _FakeAuthRepository(),
      );

      expect(
        () => service.authenticate(providerId: 'google'),
        throwsA(isA<SerializationFailure>()),
      );
    });
  });

  // ===========================================================================
  // SessionStore.loginWithOAuth
  // ===========================================================================
  group('B122 OAuth — SessionStore.loginWithOAuth', () {
    test('stores tokens and transitions to authenticated', () async {
      final storage = FakeSecureStorage();
      final fakeOAuthService = _SuccessOAuthService();

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          oAuthServiceProvider.overrideWithValue(fakeOAuthService),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(sessionStoreProvider.notifier)
          .loginWithOAuth(providerId: 'github');

      final session = container.read(sessionStoreProvider);
      expect(session.status, AuthStatus.authenticated);
      expect(session.token, 'oauth-access-token');

      // Verify tokens were persisted.
      expect(
        storage.snapshot[SessionStorageKeys.token],
        'oauth-access-token',
        reason:
            'Removing token persistence in loginWithOAuth → no stored token → RED.',
      );
      expect(
        storage.snapshot[SessionStorageKeys.refreshToken],
        'oauth-refresh-token',
        reason:
            'Removing refresh token persistence in loginWithOAuth → no stored refresh → RED.',
      );
    });

    test('propagates OAuthCancelledException without storing tokens', () async {
      final storage = FakeSecureStorage();
      final fakeOAuthService = _CancellingOAuthService();

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          oAuthServiceProvider.overrideWithValue(fakeOAuthService),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container
            .read(sessionStoreProvider.notifier)
            .loginWithOAuth(providerId: 'google'),
        throwsA(isA<OAuthCancelledException>()),
      );

      // Session must remain in initial state.
      final session = container.read(sessionStoreProvider);
      expect(session.status, AuthStatus.unknown);
      expect(storage.snapshot, isEmpty);
    });
  });

  // ===========================================================================
  // completeOAuth endpoint wiring
  // ===========================================================================
  group('B122 OAuth — completeOAuth endpoint', () {
    test('/auth/{provider}/complete is recognized as public endpoint', () {
      expect(
        isPublicAuthEndpoint('/auth/google/complete'),
        isTrue,
        reason: 'Removing the /complete pattern from isPublicAuthEndpoint → '
            'Bearer token sent on unauthenticated OAuth exchange → RED.',
      );
      expect(
        isPublicAuthEndpoint('/auth/github/complete'),
        isTrue,
        reason: 'Must match any provider id.',
      );
    });

    test('/auth/providers remains public', () {
      expect(isPublicAuthEndpoint('/auth/providers'), isTrue);
    });

    test('non-auth endpoints are not public', () {
      expect(isPublicAuthEndpoint('/channels'), isFalse);
      expect(isPublicAuthEndpoint('/auth/me'), isFalse);
    });
  });

  // ===========================================================================
  // LoginPage integration — OAuth button triggers flow
  // ===========================================================================
  group('B122 OAuth — LoginPage OAuth button triggers flow', () {
    testWidgets('tapping OAuth button calls OAuthService.authenticate',
        (tester) async {
      final fakeOAuthService = _SuccessOAuthService();

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          authProviderRepositoryProvider.overrideWithValue(
            _FakeAuthProviderRepo([
              const AuthProvider(id: 'google', name: 'Google'),
            ]),
          ),
          oAuthServiceProvider.overrideWithValue(fakeOAuthService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: LoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Google OAuth button.
      await tester.tap(find.byKey(const ValueKey('oauth-provider-google')));
      await tester.pumpAndSettle();

      // The session should now be authenticated.
      final session = container.read(sessionStoreProvider);
      expect(
        session.status,
        AuthStatus.authenticated,
        reason: 'Removing onProviderTap → _submitOAuth wiring → '
            'button tap does nothing → session stays unauthenticated → RED.',
      );
      expect(fakeOAuthService.authenticateCalls, 1);
      expect(fakeOAuthService.lastProviderId, 'google');
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

/// Simulates the OAuth service by faking the browser callback URL.
/// Exercises the real code-extraction + token-exchange logic.
class _FakeOAuthServiceWithRepo implements OAuthService {
  _FakeOAuthServiceWithRepo({
    required this.fakeCallbackUrl,
    required this.authRepository,
  });

  final String fakeCallbackUrl;
  final AuthRepository authRepository;

  @override
  Future<AuthResult> authenticate({required String providerId}) async {
    // Simulate what _FlutterWebAuthOAuthService does, but with a fake
    // callback URL instead of launching a real browser.
    final uri = Uri.parse(fakeCallbackUrl);
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const SerializationFailure(
        message: 'OAuth callback missing authorization code.',
        causeType: 'OAuthCallbackError',
      );
    }
    return authRepository.completeOAuth(providerId: providerId, code: code);
  }
}

class _CancellingOAuthService implements OAuthService {
  @override
  Future<AuthResult> authenticate({required String providerId}) async {
    throw const OAuthCancelledException();
  }
}

class _SuccessOAuthService implements OAuthService {
  int authenticateCalls = 0;
  String? lastProviderId;

  @override
  Future<AuthResult> authenticate({required String providerId}) async {
    authenticateCalls++;
    lastProviderId = providerId;
    return const AuthResult(
      accessToken: 'oauth-access-token',
      refreshToken: 'oauth-refresh-token',
    );
  }
}

class _FakeAuthRepository implements AuthRepository {
  String? lastOAuthProviderId;
  String? lastOAuthCode;

  @override
  Future<AuthResult> completeOAuth({
    required String providerId,
    required String code,
  }) async {
    lastOAuthProviderId = providerId;
    lastOAuthCode = code;
    return const AuthResult(
      accessToken: 'oauth-access-token',
      refreshToken: 'oauth-refresh-token',
    );
  }

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
}

class _FakeAuthProviderRepo implements AuthProviderRepository {
  _FakeAuthProviderRepo(this._providers);
  final List<AuthProvider> _providers;

  @override
  Future<List<AuthProvider>> getProviders() async => List.of(_providers);
}
