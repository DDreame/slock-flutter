import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/notifications/foreground_service_manager.dart';
import 'package:slock_app/core/notifications/foreground_service_lifecycle_binding.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

class FakeForegroundServiceManager implements ForegroundServiceManager {
  int startCalls = 0;
  int stopCalls = 0;
  bool _running = false;
  bool? lastAuthFlag;

  /// Simulate an already-running service (e.g. OS restored it
  /// after a process restart).
  set simulateRunning(bool value) => _running = value;

  @override
  Future<void> startService() async {
    startCalls++;
    _running = true;
  }

  @override
  Future<void> stopService() async {
    stopCalls++;
    _running = false;
  }

  @override
  Future<bool> get isRunning async => _running;

  @override
  Future<void> setAuthFlag(bool authenticated) async {
    lastAuthFlag = authenticated;
  }
}

class _ThrowingForegroundServiceManager implements ForegroundServiceManager {
  @override
  Future<void> startService() async {
    throw Exception('start failed');
  }

  @override
  Future<void> stopService() async {
    throw Exception('stop failed');
  }

  @override
  Future<bool> get isRunning async => false;

  @override
  Future<void> setAuthFlag(bool authenticated) async {}
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
      container.read(
        foregroundServiceLifecycleBindingProvider,
      );

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
      container.read(
        foregroundServiceLifecycleBindingProvider,
      );

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
      container.read(
        foregroundServiceLifecycleBindingProvider,
      );

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
      container.read(
        foregroundServiceLifecycleBindingProvider,
      );

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
      container.read(
        foregroundServiceLifecycleBindingProvider,
      );

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
      container.read(
        foregroundServiceLifecycleBindingProvider,
      );

      // Session is unknown, service never started
      await container.read(sessionStoreProvider.notifier).logout();
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.stopCalls, 0,
          reason: 'should not stop when never started');
    });

    test('restores service on boot when session exists', () async {
      // Simulate stored session
      await storage.write(
        key: 'session_token',
        value: 'saved-token',
      );
      await storage.write(
        key: 'session_refresh_token',
        value: 'saved-refresh',
      );
      await storage.write(
        key: 'session_userId',
        value: 'uid',
      );

      container.read(
        foregroundServiceLifecycleBindingProvider,
      );

      await container.read(sessionStoreProvider.notifier).restoreSession();
      await Future<void>.delayed(Duration.zero);

      container.read(appReadyProvider.notifier).state = true;
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.startCalls, 1,
          reason: 'should restore on boot with existing session');
    });

    test(
        'stops orphaned service on logout when process '
        'restarted with service already running', () async {
      // Simulate: OS kept the service alive across a
      // process restart. Dart-side state is fresh but the
      // Android service is still running.
      fakeManager.simulateRunning = true;

      container.read(
        foregroundServiceLifecycleBindingProvider,
      );

      // Session is unauthenticated (default after restart),
      // binding should detect the orphaned service and stop.
      await container.read(sessionStoreProvider.notifier).logout();
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.stopCalls, 1,
          reason: 'should stop orphaned service on '
              'unauthenticated sync');
      expect(await fakeManager.isRunning, isFalse);
    });

    test(
        'does not re-start when service is already running '
        'and user is authenticated', () async {
      // Service survived process restart and user is
      // still authenticated.
      fakeManager.simulateRunning = true;

      await storage.write(
        key: 'session_token',
        value: 'saved-token',
      );
      await storage.write(
        key: 'session_refresh_token',
        value: 'saved-refresh',
      );
      await storage.write(
        key: 'session_userId',
        value: 'uid',
      );

      container.read(
        foregroundServiceLifecycleBindingProvider,
      );

      await container.read(sessionStoreProvider.notifier).restoreSession();
      await Future<void>.delayed(Duration.zero);

      container.read(appReadyProvider.notifier).state = true;
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.startCalls, 0,
          reason: 'should not re-start already-running '
              'service');
      expect(await fakeManager.isRunning, isTrue);
    });

    test('sets auth flag true before starting service', () async {
      container.read(
        foregroundServiceLifecycleBindingProvider,
      );

      container.read(appReadyProvider.notifier).state = true;
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.lastAuthFlag, isTrue,
          reason: 'auth flag should be set before start');
      expect(fakeManager.startCalls, 1);
    });

    test('sets auth flag false before stopping service', () async {
      container.read(
        foregroundServiceLifecycleBindingProvider,
      );

      container.read(appReadyProvider.notifier).state = true;
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      await container.read(sessionStoreProvider.notifier).logout();
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.lastAuthFlag, isFalse,
          reason: 'auth flag should be cleared on logout');
      expect(fakeManager.stopCalls, 1);
    });

    test(
        'clears auth flag on unauthenticated even when '
        'service is not running', () async {
      // Simulate: auth flag was previously set true (e.g.
      // service started then was externally killed/failed).
      fakeManager.lastAuthFlag = true;

      container.read(
        foregroundServiceLifecycleBindingProvider,
      );

      // Service is not running, session goes to
      // unauthenticated — flag must still be cleared.
      await container.read(sessionStoreProvider.notifier).logout();
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.lastAuthFlag, isFalse,
          reason: 'auth flag should be cleared on '
              'unauthenticated even when service is '
              'not running');
      expect(fakeManager.stopCalls, 0,
          reason: 'should not call stop when service '
              'is not running');
    });
  });

  group('ForegroundServiceLifecycleBinding diagnostics', () {
    late FakeForegroundServiceManager fakeManager;
    late FakeSecureStorage storage;
    late DiagnosticsCollector diagnostics;
    late ProviderContainer container;

    setUp(() {
      fakeManager = FakeForegroundServiceManager();
      storage = FakeSecureStorage();
      diagnostics = DiagnosticsCollector();
      container = ProviderContainer(
        overrides: [
          foregroundServiceManagerProvider.overrideWithValue(fakeManager),
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('logs sync state on each cycle', () async {
      container.read(foregroundServiceLifecycleBindingProvider);
      await Future<void>.delayed(Duration.zero);

      final entries = diagnostics.entries
          .where((e) => e.tag == 'foreground-service')
          .toList();
      expect(entries, isNotEmpty);
      expect(entries.first.message, contains('sync:'));
      expect(entries.first.message, contains('authenticated='));
    });

    test('logs start event when service starts', () async {
      container.read(foregroundServiceLifecycleBindingProvider);

      container.read(appReadyProvider.notifier).state = true;
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      final entries = diagnostics.entries
          .where((e) =>
              e.tag == 'foreground-service' && e.message.contains('Started'))
          .toList();
      expect(entries, hasLength(1));
    });

    test('logs stop event on unauthenticated', () async {
      container.read(foregroundServiceLifecycleBindingProvider);

      container.read(appReadyProvider.notifier).state = true;
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);
      diagnostics.clear();

      await container.read(sessionStoreProvider.notifier).logout();
      await Future<void>.delayed(Duration.zero);

      final entries = diagnostics.entries
          .where((e) =>
              e.tag == 'foreground-service' && e.message.contains('Stopped'))
          .toList();
      expect(entries, hasLength(1));
    });

    test('logs error on sync failure', () async {
      final throwingManager = _ThrowingForegroundServiceManager();
      container = ProviderContainer(
        overrides: [
          foregroundServiceManagerProvider.overrideWithValue(throwingManager),
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
        ],
      );

      container.read(foregroundServiceLifecycleBindingProvider);

      container.read(appReadyProvider.notifier).state = true;
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'pw');
      await Future<void>.delayed(Duration.zero);

      final errors = diagnostics.entries
          .where((e) =>
              e.tag == 'foreground-service' &&
              e.level == DiagnosticsLevel.error)
          .toList();
      expect(errors, isNotEmpty);
      expect(errors.first.message, contains('sync error'));
    });
  });
}
