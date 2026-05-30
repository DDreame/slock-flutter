// =============================================================================
// B126 PR A — Load-bearing test for server-side logout (token revocation).
//
// Proves:
// 1. SessionStore.logout() calls AuthRepository.logout() with the refresh token.
// 2. Local cleanup still completes even when AuthRepository.logout() throws.
// 3. If no refresh token is stored, AuthRepository.logout() is NOT called.
//
// Reverting the server-side logout call → test 1 fails (logout not invoked).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';
import 'package:slock_app/features/auth/data/auth_repository.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  group('B126 — SessionStore.logout() revokes refresh token server-side', () {
    test('calls AuthRepository.logout with stored refresh token', () async {
      final storage = _FakeSecureStorage();
      storage.store[SessionStorageKeys.token] = 'access-123';
      storage.store[SessionStorageKeys.refreshToken] = 'refresh-abc';

      final authRepo = _TrackingAuthRepository();

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);

      // Set up authenticated state.
      final notifier = container.read(sessionStoreProvider.notifier);
      await notifier.restoreSession();
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.authenticated,
      );

      // Perform logout.
      await notifier.logout();

      // Verify server-side revocation was called with the correct token.
      expect(
        authRepo.logoutCalls,
        ['refresh-abc'],
        reason: 'Reverting the server-side logout call → logout not invoked '
            '→ RED. SessionStore.logout must call AuthRepository.logout '
            'with the refresh token.',
      );

      // Verify local state is cleared.
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(storage.store[SessionStorageKeys.token], isNull);
      expect(storage.store[SessionStorageKeys.refreshToken], isNull);
    });

    test('local cleanup completes even when server logout throws', () async {
      final storage = _FakeSecureStorage();
      storage.store[SessionStorageKeys.token] = 'access-123';
      storage.store[SessionStorageKeys.refreshToken] = 'refresh-abc';

      final authRepo = _FailingLogoutAuthRepository();

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(sessionStoreProvider.notifier);
      await notifier.restoreSession();

      // Should NOT throw — logout is fire-and-forget.
      await notifier.logout();

      // Local state must still be cleared despite server error.
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(storage.store[SessionStorageKeys.token], isNull);
    });

    test('does not call AuthRepository.logout when no refresh token', () async {
      final storage = _FakeSecureStorage();
      // Only access token, no refresh token.
      storage.store[SessionStorageKeys.token] = 'access-123';

      final authRepo = _TrackingAuthRepository();

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(sessionStoreProvider.notifier);
      // restoreSession without refreshToken → stays unknown/unauthenticated.
      // Force authenticated state for the test.
      await notifier.restoreSession();

      await notifier.logout();

      // Should NOT have called server logout.
      expect(authRepo.logoutCalls, isEmpty);
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> store = {};

  @override
  Future<String?> read({required String key}) async => store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    store.remove(key);
  }
}

class _TrackingAuthRepository implements AuthRepository {
  final List<String> logoutCalls = [];

  @override
  Future<void> logout({required String refreshToken}) async {
    logoutCalls.add(refreshToken);
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async =>
      const AuthResult(accessToken: 'a', refreshToken: 'r');

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  }) async =>
      const AuthResult(accessToken: 'a', refreshToken: 'r');

  @override
  Future<AuthResult> completeOAuth({
    required String providerId,
    required String code,
  }) async =>
      const AuthResult(accessToken: 'a', refreshToken: 'r');

  @override
  Future<AuthUser> getMe() async => const AuthUser(id: 'uid', name: 'User');

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

class _FailingLogoutAuthRepository extends _TrackingAuthRepository {
  @override
  Future<void> logout({required String refreshToken}) async {
    throw const NetworkFailure(message: 'Connection refused');
  }
}
