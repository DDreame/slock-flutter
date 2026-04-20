import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';
import 'package:slock_app/core/storage/server_selection_storage_keys.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';
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

class FakeServerListRepository implements ServerListRepository {
  @override
  Future<List<ServerSummary>> loadServers() async => const [];
}

class FakeNotificationInitializer implements NotificationInitializer {
  int initCount = 0;

  @override
  Future<void> init() async {
    initCount++;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.unknown;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async => null;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => const Stream.empty();
}

void main() {
  late ProviderContainer container;
  late FakeSecureStorage fakeStorage;
  late FakeNotificationInitializer fakeNotificationInitializer;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    fakeNotificationInitializer = FakeNotificationInitializer();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(fakeStorage),
        serverListRepositoryProvider.overrideWithValue(
          FakeServerListRepository(),
        ),
        notificationInitializerProvider.overrideWithValue(
          fakeNotificationInitializer,
        ),
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

    test('sets appReady to true after authenticated bootstrap', () async {
      fakeStorage._store[SessionStorageKeys.token] = 'saved-token';
      fakeStorage._store[SessionStorageKeys.userId] = 'user-1';
      fakeStorage._store[ServerSelectionStorageKeys.selectedServerId] =
          'server-1';

      expect(container.read(appReadyProvider), isFalse);

      await container.read(splashControllerProvider.future);

      expect(container.read(appReadyProvider), isTrue);
    });

    test('sets appReady to true after unauthenticated bootstrap', () async {
      expect(container.read(appReadyProvider), isFalse);

      await container.read(splashControllerProvider.future);

      expect(container.read(sessionStoreProvider).status,
          AuthStatus.unauthenticated);
      expect(container.read(appReadyProvider), isTrue);
    });

    test('calls notification store init during bootstrap', () async {
      await container.read(splashControllerProvider.future);

      expect(fakeNotificationInitializer.initCount, 1);
    });

    test('calls notification store init during authenticated bootstrap',
        () async {
      fakeStorage._store[SessionStorageKeys.token] = 'saved-token';
      fakeStorage._store[SessionStorageKeys.userId] = 'user-1';

      await container.read(splashControllerProvider.future);

      expect(fakeNotificationInitializer.initCount, 1);
    });
  });
}
