import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/network/network_config.dart';
import 'package:slock_app/core/notifications/background_sync_manager.dart';
import 'package:slock_app/core/notifications/background_sync_lifecycle_binding.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

class FakeBackgroundSyncManager implements BackgroundSyncManager {
  int scheduleCalls = 0;
  int cancelCalls = 0;
  int clearConfigCalls = 0;
  String? lastApiBaseUrl;
  String? lastServerId;

  @override
  Future<void> schedulePeriodicSync() async {
    scheduleCalls++;
  }

  @override
  Future<void> cancelPeriodicSync() async {
    cancelCalls++;
  }

  @override
  Future<void> persistSyncConfig({
    required String apiBaseUrl,
    required String serverId,
  }) async {
    lastApiBaseUrl = apiBaseUrl;
    lastServerId = serverId;
  }

  @override
  Future<void> clearSyncConfig() async {
    clearConfigCalls++;
  }
}

void main() {
  group('BackgroundSyncLifecycleBinding', () {
    late FakeBackgroundSyncManager fakeManager;
    late FakeSecureStorage storage;
    late ProviderContainer container;

    setUp(() {
      fakeManager = FakeBackgroundSyncManager();
      storage = FakeSecureStorage();
      container = ProviderContainer(
        overrides: [
          backgroundSyncManagerProvider.overrideWithValue(fakeManager),
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
          networkConfigProvider.overrideWithValue(
            const NetworkConfig(
              baseUrl: 'https://api.test.com',
            ),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
        'does not schedule sync until authenticated, '
        'bootstrap ready, and app paused', () async {
      container.read(
        backgroundSyncLifecycleBindingProvider,
      );

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.scheduleCalls, 0,
          reason: 'should not schedule before '
              'bootstrap ready and app paused');
    });

    test(
        'schedules sync when authenticated, '
        'bootstrap ready, and app goes to paused', () async {
      container.read(
        backgroundSyncLifecycleBindingProvider,
      );

      // Set up server selection so config can be persisted
      await container
          .read(serverSelectionStoreProvider.notifier)
          .selectServer('srv-1');

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      container.read(appReadyProvider.notifier).state = true;
      await Future<void>.delayed(Duration.zero);

      // Simulate app going to background
      container
          .read(notificationStoreProvider.notifier)
          .setLifecycleStatus(AppLifecycleStatus.paused);
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.scheduleCalls, 1);
    });

    test('persists sync config before scheduling', () async {
      container.read(
        backgroundSyncLifecycleBindingProvider,
      );

      await container
          .read(serverSelectionStoreProvider.notifier)
          .selectServer('srv-42');

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      container.read(appReadyProvider.notifier).state = true;
      await Future<void>.delayed(Duration.zero);

      container
          .read(notificationStoreProvider.notifier)
          .setLifecycleStatus(AppLifecycleStatus.paused);
      await Future<void>.delayed(Duration.zero);

      expect(
        fakeManager.lastApiBaseUrl,
        'https://api.test.com',
      );
      expect(fakeManager.lastServerId, 'srv-42');
    });

    test('does not schedule when no server selected', () async {
      container.read(
        backgroundSyncLifecycleBindingProvider,
      );

      // No server selected
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      container.read(appReadyProvider.notifier).state = true;
      await Future<void>.delayed(Duration.zero);

      container
          .read(notificationStoreProvider.notifier)
          .setLifecycleStatus(AppLifecycleStatus.paused);
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.scheduleCalls, 0,
          reason: 'should not schedule without '
              'a selected server');
    });

    test('cancels sync and clears config on logout', () async {
      container.read(
        backgroundSyncLifecycleBindingProvider,
      );

      await container
          .read(serverSelectionStoreProvider.notifier)
          .selectServer('srv-1');

      container.read(appReadyProvider.notifier).state = true;
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      // Simulate background + schedule
      container
          .read(notificationStoreProvider.notifier)
          .setLifecycleStatus(AppLifecycleStatus.paused);
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.scheduleCalls, 1);

      // Logout
      await container.read(sessionStoreProvider.notifier).logout();
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.cancelCalls, 1);
      expect(fakeManager.clearConfigCalls, 1);
    });

    test('does not schedule when app is resumed', () async {
      container.read(
        backgroundSyncLifecycleBindingProvider,
      );

      await container
          .read(serverSelectionStoreProvider.notifier)
          .selectServer('srv-1');

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      container.read(appReadyProvider.notifier).state = true;
      await Future<void>.delayed(Duration.zero);

      // App stays resumed (default state)
      expect(fakeManager.scheduleCalls, 0,
          reason: 'should not schedule when app '
              'is in foreground');
    });

    test(
        'does not schedule twice on redundant '
        'paused events', () async {
      container.read(
        backgroundSyncLifecycleBindingProvider,
      );

      await container
          .read(serverSelectionStoreProvider.notifier)
          .selectServer('srv-1');

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      container.read(appReadyProvider.notifier).state = true;
      await Future<void>.delayed(Duration.zero);

      container
          .read(notificationStoreProvider.notifier)
          .setLifecycleStatus(AppLifecycleStatus.paused);
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.scheduleCalls, 1);

      // Redundant paused event
      container
          .read(notificationStoreProvider.notifier)
          .setLifecycleStatus(AppLifecycleStatus.paused);
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.scheduleCalls, 1,
          reason: 'should not schedule again '
              'when already scheduled');
    });

    test('cancels sync when app returns to foreground', () async {
      container.read(
        backgroundSyncLifecycleBindingProvider,
      );

      await container
          .read(serverSelectionStoreProvider.notifier)
          .selectServer('srv-1');

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      container.read(appReadyProvider.notifier).state = true;
      await Future<void>.delayed(Duration.zero);

      // Go to background
      container
          .read(notificationStoreProvider.notifier)
          .setLifecycleStatus(AppLifecycleStatus.paused);
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.scheduleCalls, 1);

      // Return to foreground
      container
          .read(notificationStoreProvider.notifier)
          .setLifecycleStatus(AppLifecycleStatus.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.cancelCalls, 1,
          reason: 'should cancel background sync '
              'when app returns to foreground');
    });
  });
}
