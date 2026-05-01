import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/notifications/foreground_service_manager.dart';
import 'package:slock_app/core/notifications/foreground_service_lifecycle_binding.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

class FakeForegroundServiceManager implements ForegroundServiceManager {
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> startService() async {
    startCalls++;
  }

  @override
  Future<void> stopService() async {
    stopCalls++;
  }

  @override
  Future<bool> get isRunning async => startCalls > stopCalls;
}

void main() {
  group('ForegroundServiceLifecycleBinding', () {
    late FakeForegroundServiceManager fakeManager;
    late FakeSecureStorage storage;
    late ProviderContainer container;

    setUp(() {
      fakeManager = FakeForegroundServiceManager();
      storage = FakeSecureStorage();
      container = ProviderContainer(
        overrides: [
          foregroundServiceManagerProvider.overrideWithValue(fakeManager),
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
        'does not start service until both authenticated '
        'and bootstrap ready', () async {
      container.read(foregroundServiceLifecycleBindingProvider);

      // Authenticate but don't set appReady
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.startCalls, 0,
          reason: 'should not start before bootstrap');
    });

    test(
        'starts service when authenticated and '
        'bootstrap becomes ready', () async {
      container.read(foregroundServiceLifecycleBindingProvider);

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      container.read(appReadyProvider.notifier).state = true;
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.startCalls, 1);
    });

    test(
        'starts service when bootstrap ready first, '
        'then authenticated', () async {
      container.read(foregroundServiceLifecycleBindingProvider);

      container.read(appReadyProvider.notifier).state = true;
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.startCalls, 0, reason: 'not authenticated yet');

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.startCalls, 1);
    });

    test('stops service on logout', () async {
      container.read(foregroundServiceLifecycleBindingProvider);

      container.read(appReadyProvider.notifier).state = true;
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.startCalls, 1);

      await container.read(sessionStoreProvider.notifier).logout();
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.stopCalls, 1);
    });

    test('does not start service twice when already running', () async {
      container.read(foregroundServiceLifecycleBindingProvider);

      container.read(appReadyProvider.notifier).state = true;
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.startCalls, 1);

      // Trigger another session event (no state change)
      container.read(appReadyProvider.notifier).state = true;
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.startCalls, 1,
          reason: 'should not start again when already running');
    });

    test('does not stop service when already stopped', () async {
      container.read(foregroundServiceLifecycleBindingProvider);

      // Session is unknown, service never started
      await container.read(sessionStoreProvider.notifier).logout();
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.stopCalls, 0,
          reason: 'should not stop when never started');
    });

    test('restores service on boot when session exists', () async {
      // Simulate stored session by writing token before restoring
      await storage.write(key: 'session_token', value: 'saved-token');
      await storage.write(key: 'session_userId', value: 'uid');

      container.read(foregroundServiceLifecycleBindingProvider);

      await container.read(sessionStoreProvider.notifier).restoreSession();
      await Future<void>.delayed(Duration.zero);

      container.read(appReadyProvider.notifier).state = true;
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.startCalls, 1,
          reason: 'should restore on boot with existing session');
    });
  });
}
