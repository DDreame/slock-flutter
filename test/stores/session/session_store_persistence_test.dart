import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/core/network/auth_token_provider.dart';
import 'package:slock_app/core/network/network_config.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/server_selection_storage_keys.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';
import 'package:slock_app/features/auth/data/auth_repository.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

class FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  Map<String, String> get snapshot => Map.unmodifiable(_store);
}

class FakeAuthRepository implements AuthRepository {
  const FakeAuthRepository({this.emailVerified = true});

  final bool emailVerified;

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async =>
      const AuthResult(
        accessToken: 'fake-access-token',
        refreshToken: 'fake-refresh-token',
      );

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  }) async =>
      const AuthResult(
        accessToken: 'fake-access-token',
        refreshToken: 'fake-refresh-token',
      );

  @override
  Future<AuthUser> getMe() async => AuthUser(
        id: 'fake-uid',
        name: 'Fake User',
        emailVerified: emailVerified,
      );

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

/// A [FakeAuthRepository] whose [getMe] can be configured with a callback,
/// allowing tests to inject side-effects (e.g. simulating the Dio interceptor
/// calling [SessionStore.updateTokens] during a 401-retry).
class _ConfigurableAuthRepository extends FakeAuthRepository {
  _ConfigurableAuthRepository({this.getMeHandler});

  final Future<AuthUser> Function()? getMeHandler;

  @override
  Future<AuthUser> getMe() async {
    if (getMeHandler != null) {
      return getMeHandler!();
    }
    return super.getMe();
  }
}

void main() {
  late ProviderContainer container;
  late FakeSecureStorage fakeStorage;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(fakeStorage),
        authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SessionStore persistence', () {
    test('restoreSession with stored token transitions to authenticated',
        () async {
      fakeStorage._store[SessionStorageKeys.token] = 'saved-token';
      fakeStorage._store[SessionStorageKeys.refreshToken] = 'saved-refresh';
      fakeStorage._store[SessionStorageKeys.userId] = 'saved-uid';
      fakeStorage._store[SessionStorageKeys.displayName] = 'Alice';

      await container.read(sessionStoreProvider.notifier).restoreSession();
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.authenticated);
      expect(state.token, 'saved-token');
      expect(state.userId, 'fake-uid');
      expect(state.displayName, 'Fake User');
      expect(state.emailVerified, isTrue);
    });

    test('restoreSession with empty storage transitions to unauthenticated',
        () async {
      await container.read(sessionStoreProvider.notifier).restoreSession();
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.unauthenticated);
      expect(state.token, isNull);
    });

    test('login persists session to storage', () async {
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@example.com', password: 'password');

      expect(
        fakeStorage.snapshot[SessionStorageKeys.token],
        'fake-access-token',
      );
      expect(
        fakeStorage.snapshot[SessionStorageKeys.refreshToken],
        'fake-refresh-token',
      );
      expect(fakeStorage.snapshot[SessionStorageKeys.userId], 'fake-uid');
      expect(fakeStorage.snapshot[SessionStorageKeys.displayName], 'Fake User');
      expect(
        container.read(sessionStoreProvider).emailVerified,
        isTrue,
      );
    });

    test('register persists session to storage', () async {
      await container.read(sessionStoreProvider.notifier).register(
            email: 'test@example.com',
            password: 'password',
            displayName: 'Test User',
          );

      expect(
        fakeStorage.snapshot[SessionStorageKeys.token],
        'fake-access-token',
      );
      expect(
        fakeStorage.snapshot[SessionStorageKeys.refreshToken],
        'fake-refresh-token',
      );
      expect(fakeStorage.snapshot[SessionStorageKeys.userId], 'fake-uid');
      expect(
        fakeStorage.snapshot[SessionStorageKeys.displayName],
        'Fake User',
      );
      expect(
        container.read(sessionStoreProvider).emailVerified,
        isTrue,
      );
    });

    test('logout clears session-owned keys from storage', () async {
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@example.com', password: 'password');
      expect(fakeStorage.snapshot, isNotEmpty);

      await container.read(sessionStoreProvider.notifier).logout();

      expect(fakeStorage.snapshot[SessionStorageKeys.token], isNull);
      expect(fakeStorage.snapshot[SessionStorageKeys.refreshToken], isNull);
      expect(fakeStorage.snapshot[SessionStorageKeys.userId], isNull);
      expect(fakeStorage.snapshot[SessionStorageKeys.displayName], isNull);

      final state = container.read(sessionStoreProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.token, isNull);
    });

    test('logout does not clear non-session keys', () async {
      fakeStorage._store['other_key'] = 'other_value';

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@example.com', password: 'password');
      await container.read(sessionStoreProvider.notifier).logout();

      expect(fakeStorage.snapshot['other_key'], 'other_value');
    });

    test(
        'restoreSession with empty storage clears stale in-memory session fields',
        () async {
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@example.com', password: 'password');
      expect(container.read(sessionStoreProvider).token, isNotNull);

      // Clear storage but leave in-memory state as authenticated.
      await SessionStorageKeys.clear(fakeStorage);

      await container.read(sessionStoreProvider.notifier).restoreSession();
      final state = container.read(sessionStoreProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.token, isNull);
      expect(state.userId, isNull);
      expect(state.displayName, isNull);
    });

    test('full lifecycle: login -> restore -> logout -> restore', () async {
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'user@slock.it', password: 'secret');
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.authenticated,
      );
      expect(fakeStorage.snapshot[SessionStorageKeys.token], isNotNull);

      // New container simulates app restart.
      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
        ],
      );

      await container.read(sessionStoreProvider.notifier).restoreSession();
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.authenticated,
      );
      expect(container.read(sessionStoreProvider).token, 'fake-access-token');

      await container.read(sessionStoreProvider.notifier).logout();
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.unauthenticated,
      );

      // Another restart after logout.
      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
        ],
      );

      await container.read(sessionStoreProvider.notifier).restoreSession();
      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    test('updateTokens persists both tokens and updates in-memory state',
        () async {
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@example.com', password: 'password');

      await container.read(sessionStoreProvider.notifier).updateTokens(
            accessToken: 'new-access-token',
            refreshToken: 'new-refresh-token',
          );

      final state = container.read(sessionStoreProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.token, 'new-access-token');

      expect(
        fakeStorage.snapshot[SessionStorageKeys.token],
        'new-access-token',
      );
      expect(
        fakeStorage.snapshot[SessionStorageKeys.refreshToken],
        'new-refresh-token',
      );
    });

    test('logout clears server selection state and storage', () async {
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'test@example.com', password: 'password');
      await container
          .read(serverSelectionStoreProvider.notifier)
          .selectServer('server-1');
      expect(
        container.read(serverSelectionStoreProvider).selectedServerId,
        'server-1',
      );
      expect(
        fakeStorage.snapshot[ServerSelectionStorageKeys.selectedServerId],
        'server-1',
      );

      await container.read(sessionStoreProvider.notifier).logout();

      expect(
        container.read(sessionStoreProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(
        container.read(serverSelectionStoreProvider).selectedServerId,
        isNull,
      );
      expect(
        fakeStorage.snapshot[ServerSelectionStorageKeys.selectedServerId],
        isNull,
      );
    });
  });

  group('Session restore requires both tokens (#378)', () {
    test(
        'restoreSession with access token only (no refresh) clears and goes '
        'unauthenticated', () async {
      // Seed ONLY access token — no refresh token.
      fakeStorage._store[SessionStorageKeys.token] = 'orphan-access';

      await container.read(sessionStoreProvider.notifier).restoreSession();
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.unauthenticated);
      expect(state.token, isNull);
      // Storage should be cleaned up.
      expect(fakeStorage.snapshot[SessionStorageKeys.token], isNull);
    });

    test(
        'restoreSession with refresh token only (no access) goes '
        'unauthenticated', () async {
      // Seed ONLY refresh token — no access token.
      fakeStorage._store[SessionStorageKeys.refreshToken] = 'orphan-refresh';

      await container.read(sessionStoreProvider.notifier).restoreSession();
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.unauthenticated);
      expect(state.token, isNull);
      // Orphan refresh token should be cleaned up.
      expect(fakeStorage.snapshot[SessionStorageKeys.refreshToken], isNull);
    });

    test('restoreSession with both tokens transitions to authenticated',
        () async {
      fakeStorage._store[SessionStorageKeys.token] = 'access-1';
      fakeStorage._store[SessionStorageKeys.refreshToken] = 'refresh-1';

      await container.read(sessionStoreProvider.notifier).restoreSession();
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.authenticated);
      expect(state.token, 'access-1');
    });
  });

  group('Stale-token clobber prevention (#378)', () {
    test(
        'restore path: token refresh during getMe keeps fresh token, '
        'not stale stored token', () async {
      // Simulate: storage has stale-token, interceptor refreshes mid-getMe.
      fakeStorage._store[SessionStorageKeys.token] = 'stale-token';
      fakeStorage._store[SessionStorageKeys.refreshToken] = 'stored-refresh';

      late SessionStore sessionStore;
      final repo = _ConfigurableAuthRepository(
        getMeHandler: () async {
          // Simulate Dio interceptor refreshing token during the getMe call.
          await sessionStore.updateTokens(
            accessToken: 'fresh-token',
            refreshToken: 'fresh-refresh',
          );
          return const AuthUser(
            id: 'user-1',
            name: 'Alice',
            emailVerified: true,
          );
        },
      );

      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      sessionStore = container.read(sessionStoreProvider.notifier);

      await sessionStore.restoreSession();
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.authenticated);
      // CRITICAL: must use fresh token, not stale-token.
      expect(state.token, 'fresh-token');
      expect(state.userId, 'user-1');
      expect(state.displayName, 'Alice');
      // Storage must reflect fresh token.
      expect(fakeStorage.snapshot[SessionStorageKeys.token], 'fresh-token');
      expect(
        fakeStorage.snapshot[SessionStorageKeys.refreshToken],
        'fresh-refresh',
      );
    });

    test(
        'login path: token refresh during getMe keeps fresh token, '
        'not original access token', () async {
      late SessionStore sessionStore;
      final repo = _ConfigurableAuthRepository(
        getMeHandler: () async {
          // Simulate interceptor refreshing token during the getMe call
          // that is triggered inside _hydrateAuthenticatedSession.
          await sessionStore.updateTokens(
            accessToken: 'refreshed-access',
            refreshToken: 'refreshed-refresh',
          );
          return const AuthUser(
            id: 'user-1',
            name: 'Alice',
            emailVerified: true,
          );
        },
      );

      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      sessionStore = container.read(sessionStoreProvider.notifier);

      await sessionStore.login(email: 'a@b.com', password: 'pass');
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.authenticated);
      // Must use refreshed token, not original 'fake-access-token'.
      expect(state.token, 'refreshed-access');
      expect(
          fakeStorage.snapshot[SessionStorageKeys.token], 'refreshed-access');
    });

    test(
        'register path: token refresh during getMe keeps fresh token, '
        'not original access token', () async {
      late SessionStore sessionStore;
      final repo = _ConfigurableAuthRepository(
        getMeHandler: () async {
          await sessionStore.updateTokens(
            accessToken: 'refreshed-access',
            refreshToken: 'refreshed-refresh',
          );
          return const AuthUser(
            id: 'user-1',
            name: 'Alice',
            emailVerified: true,
          );
        },
      );

      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      sessionStore = container.read(sessionStoreProvider.notifier);

      await sessionStore.register(
        email: 'a@b.com',
        password: 'pass',
        displayName: 'Test',
      );
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.authenticated);
      expect(state.token, 'refreshed-access');
      expect(
          fakeStorage.snapshot[SessionStorageKeys.token], 'refreshed-access');
    });
  });

  group('Auth failure during hydration clears session (#378)', () {
    test('getMe 401 during restore clears session', () async {
      fakeStorage._store[SessionStorageKeys.token] = 'expired-token';
      fakeStorage._store[SessionStorageKeys.refreshToken] = 'expired-refresh';
      fakeStorage._store[SessionStorageKeys.userId] = 'saved-uid';

      final repo = _ConfigurableAuthRepository(
        getMeHandler: () async {
          throw const UnauthorizedFailure(
            message: 'Token expired',
            statusCode: 401,
          );
        },
      );

      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await container.read(sessionStoreProvider.notifier).restoreSession();
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.unauthenticated);
      expect(state.token, isNull);
      // Storage must be cleared.
      expect(fakeStorage.snapshot[SessionStorageKeys.token], isNull);
      expect(fakeStorage.snapshot[SessionStorageKeys.refreshToken], isNull);
    });

    test('getMe 403 during restore clears session', () async {
      fakeStorage._store[SessionStorageKeys.token] = 'banned-token';
      fakeStorage._store[SessionStorageKeys.refreshToken] = 'banned-refresh';

      final repo = _ConfigurableAuthRepository(
        getMeHandler: () async {
          throw const ForbiddenFailure(
            message: 'Forbidden',
            statusCode: 403,
          );
        },
      );

      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await container.read(sessionStoreProvider.notifier).restoreSession();
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.unauthenticated);
      expect(state.token, isNull);
    });

    test('getMe 401 during login clears session', () async {
      final repo = _ConfigurableAuthRepository(
        getMeHandler: () async {
          throw const UnauthorizedFailure(
            message: 'Token expired immediately',
            statusCode: 401,
          );
        },
      );

      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pass');
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.unauthenticated);
      expect(state.token, isNull);
      expect(fakeStorage.snapshot[SessionStorageKeys.token], isNull);
      expect(fakeStorage.snapshot[SessionStorageKeys.refreshToken], isNull);
    });

    test('getMe 401 during register clears session', () async {
      final repo = _ConfigurableAuthRepository(
        getMeHandler: () async {
          throw const UnauthorizedFailure(
            message: 'Token expired immediately',
            statusCode: 401,
          );
        },
      );

      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await container.read(sessionStoreProvider.notifier).register(
            email: 'a@b.com',
            password: 'pass',
            displayName: 'Test',
          );
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.unauthenticated);
      expect(state.token, isNull);
      expect(fakeStorage.snapshot[SessionStorageKeys.token], isNull);
    });

    test(
        'getMe network failure during restore does NOT clear session '
        '(only auth failures clear)', () async {
      fakeStorage._store[SessionStorageKeys.token] = 'good-token';
      fakeStorage._store[SessionStorageKeys.refreshToken] = 'good-refresh';
      fakeStorage._store[SessionStorageKeys.userId] = 'saved-uid';
      fakeStorage._store[SessionStorageKeys.displayName] = 'Alice';

      final repo = _ConfigurableAuthRepository(
        getMeHandler: () async {
          throw const NetworkFailure(message: 'No internet');
        },
      );

      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await container.read(sessionStoreProvider.notifier).restoreSession();
      final state = container.read(sessionStoreProvider);

      // Network failure should NOT clear the session — keep fallback data.
      expect(state.status, AuthStatus.authenticated);
      expect(state.token, 'good-token');
      expect(state.userId, 'saved-uid');
      expect(state.displayName, 'Alice');
    });
  });

  group('Post-login auth header transport (#378)', () {
    test(
        'login path: requestHeadersBuilderProvider returns correct '
        'Authorization after login', () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
          networkConfigProvider.overrideWithValue(
            const NetworkConfig(baseUrl: 'https://api.test'),
          ),
        ],
      );

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pass');

      final buildHeaders = container.read(requestHeadersBuilderProvider);
      final headers = await buildHeaders();

      expect(
        headers['Authorization'],
        'Bearer fake-access-token',
        reason: 'next request after login must carry the returned access token',
      );
    });

    test(
        'login path with mid-getMe refresh: requestHeadersBuilderProvider '
        'returns refreshed token, not original', () async {
      late SessionStore sessionStore;
      final repo = _ConfigurableAuthRepository(
        getMeHandler: () async {
          // Simulate Dio interceptor refreshing token during the getMe call.
          await sessionStore.updateTokens(
            accessToken: 'refreshed-access',
            refreshToken: 'refreshed-refresh',
          );
          return const AuthUser(
            id: 'user-1',
            name: 'Alice',
            emailVerified: true,
          );
        },
      );

      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(repo),
          networkConfigProvider.overrideWithValue(
            const NetworkConfig(baseUrl: 'https://api.test'),
          ),
        ],
      );
      sessionStore = container.read(sessionStoreProvider.notifier);

      await sessionStore.login(email: 'a@b.com', password: 'pass');

      final buildHeaders = container.read(requestHeadersBuilderProvider);
      final headers = await buildHeaders();

      expect(
        headers['Authorization'],
        'Bearer refreshed-access',
        reason: 'next request after login+refresh must carry the '
            'fresh token, not the original access token',
      );
    });

    test(
        'restore path: requestHeadersBuilderProvider returns correct '
        'Authorization after restoreSession', () async {
      fakeStorage._store[SessionStorageKeys.token] = 'stored-access';
      fakeStorage._store[SessionStorageKeys.refreshToken] = 'stored-refresh';

      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
          networkConfigProvider.overrideWithValue(
            const NetworkConfig(baseUrl: 'https://api.test'),
          ),
        ],
      );

      await container.read(sessionStoreProvider.notifier).restoreSession();

      final buildHeaders = container.read(requestHeadersBuilderProvider);
      final headers = await buildHeaders();

      expect(
        headers['Authorization'],
        'Bearer stored-access',
        reason: 'next request after restore must carry the stored access token',
      );
    });

    test(
        'restore path with mid-getMe refresh: requestHeadersBuilderProvider '
        'returns refreshed token', () async {
      fakeStorage._store[SessionStorageKeys.token] = 'stale-access';
      fakeStorage._store[SessionStorageKeys.refreshToken] = 'stored-refresh';

      late SessionStore sessionStore;
      final repo = _ConfigurableAuthRepository(
        getMeHandler: () async {
          await sessionStore.updateTokens(
            accessToken: 'fresh-access',
            refreshToken: 'fresh-refresh',
          );
          return const AuthUser(
            id: 'user-1',
            name: 'Alice',
            emailVerified: true,
          );
        },
      );

      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          authRepositoryProvider.overrideWithValue(repo),
          networkConfigProvider.overrideWithValue(
            const NetworkConfig(baseUrl: 'https://api.test'),
          ),
        ],
      );
      sessionStore = container.read(sessionStoreProvider.notifier);

      await sessionStore.restoreSession();

      final buildHeaders = container.read(requestHeadersBuilderProvider);
      final headers = await buildHeaders();

      expect(
        headers['Authorization'],
        'Bearer fresh-access',
        reason: 'next request after restore+refresh must carry the '
            'fresh token, not the stale stored token',
      );
    });
  });
}
