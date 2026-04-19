import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';
import 'package:slock_app/core/storage/server_selection_storage_keys.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';
import 'package:slock_app/stores/server_selection/server_selection_state.dart';
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
}

void main() {
  late ProviderContainer container;
  late FakeSecureStorage fakeStorage;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(fakeStorage),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SplashController', () {
    test('restores session and server selection when authenticated', () async {
      fakeStorage._store[SessionStorageKeys.token] = 'saved-token';
      fakeStorage._store[SessionStorageKeys.userId] = 'user-1';
      fakeStorage._store[ServerSelectionStorageKeys.selectedServerId] =
          'server-1';

      await container.read(splashControllerProvider.future);

      final session = container.read(sessionStoreProvider);
      expect(session.status, AuthStatus.authenticated);
      expect(session.token, 'saved-token');

      final selection = container.read(serverSelectionStoreProvider);
      expect(selection.selectedServerId, 'server-1');
    });

    test('does not restore server selection when unauthenticated', () async {
      fakeStorage._store[ServerSelectionStorageKeys.selectedServerId] =
          'server-1';

      await container.read(splashControllerProvider.future);

      final session = container.read(sessionStoreProvider);
      expect(session.status, AuthStatus.unauthenticated);

      final selection = container.read(serverSelectionStoreProvider);
      expect(selection.selectedServerId, isNull);
    });

    test('handles no stored session and no stored selection', () async {
      await container.read(splashControllerProvider.future);

      final session = container.read(sessionStoreProvider);
      expect(session.status, AuthStatus.unauthenticated);

      final selection = container.read(serverSelectionStoreProvider);
      expect(selection.selectedServerId, isNull);
    });
  });
}
