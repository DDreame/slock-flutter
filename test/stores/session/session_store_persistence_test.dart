import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  const FakeAuthRepository();

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
  Future<AuthUser> getMe() async =>
      const AuthUser(id: 'fake-uid', name: 'Fake User');

  @override
  Future<void> requestPasswordReset({required String email}) async {}
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
      fakeStorage._store[SessionStorageKeys.userId] = 'saved-uid';
      fakeStorage._store[SessionStorageKeys.displayName] = 'Alice';

      await container.read(sessionStoreProvider.notifier).restoreSession();
      final state = container.read(sessionStoreProvider);

      expect(state.status, AuthStatus.authenticated);
      expect(state.token, 'saved-token');
      expect(state.userId, 'saved-uid');
      expect(state.displayName, 'Alice');
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
}
