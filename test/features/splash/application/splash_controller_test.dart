import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';
import 'package:slock_app/core/storage/server_selection_storage_keys.dart';
import 'package:slock_app/core/telemetry/crash_detected_provider.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
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
  Completer<void>? _initCompleter;
  bool shouldFail = false;

  void holdInit() {
    _initCompleter = Completer<void>();
  }

  void releaseInit() {
    _initCompleter?.complete();
  }

  @override
  Future<void> init() async {
    if (_initCompleter != null) {
      await _initCompleter!.future;
    }
    if (shouldFail) {
      throw Exception('notification init failed');
    }
    initCount++;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.unknown;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      NotificationPermissionStatus.unknown;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async => null;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => const Stream.empty();

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) async {}
}

void main() {
  late ProviderContainer container;
  late FakeSecureStorage fakeStorage;
  late FakeNotificationInitializer fakeNotificationInitializer;
  late DiagnosticsCollector diagnostics;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    fakeNotificationInitializer = FakeNotificationInitializer();
    diagnostics = DiagnosticsCollector();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(fakeStorage),
        serverListRepositoryProvider.overrideWithValue(
          FakeServerListRepository(),
        ),
        notificationInitializerProvider.overrideWithValue(
          fakeNotificationInitializer,
        ),
        diagnosticsCollectorProvider.overrideWithValue(diagnostics),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SplashController', () {
    test('restores session and server selection when authenticated', () async {
      fakeStorage._store[SessionStorageKeys.token] = 'saved-token';
      fakeStorage._store[SessionStorageKeys.refreshToken] = 'saved-refresh';
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
      fakeStorage._store[SessionStorageKeys.refreshToken] = 'saved-refresh';
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

    test(
        'notification init is deferred — appReady is true before init completes',
        () async {
      fakeNotificationInitializer.holdInit();

      await container.read(splashControllerProvider.future);

      expect(container.read(appReadyProvider), isTrue);
      expect(fakeNotificationInitializer.initCount, 0);

      fakeNotificationInitializer.releaseInit();
      await Future<void>.delayed(Duration.zero);
      expect(fakeNotificationInitializer.initCount, 1);
    });

    test('notification init completes after bootstrap', () async {
      await container.read(splashControllerProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(fakeNotificationInitializer.initCount, 1);
    });

    test('notification init completes after authenticated bootstrap', () async {
      fakeStorage._store[SessionStorageKeys.token] = 'saved-token';
      fakeStorage._store[SessionStorageKeys.refreshToken] = 'saved-refresh';
      fakeStorage._store[SessionStorageKeys.userId] = 'user-1';

      await container.read(splashControllerProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(fakeNotificationInitializer.initCount, 1);
    });

    test('notification init failure is logged to diagnostics', () async {
      fakeNotificationInitializer.shouldFail = true;

      await container.read(splashControllerProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(appReadyProvider), isTrue);
      expect(diagnostics.entries, hasLength(1));
      expect(diagnostics.entries.first.level, DiagnosticsLevel.error);
      expect(diagnostics.entries.first.tag, 'splash');
    });

    test('sets crashDetectedProvider to true when crash marker exists',
        () async {
      // Seed a crash marker.
      fakeStorage._store['crash_marker'] = 'true';
      fakeStorage._store['crash_marker_timestamp'] =
          DateTime.now().toIso8601String();

      expect(container.read(crashDetectedProvider), isFalse);

      await container.read(splashControllerProvider.future);

      expect(container.read(crashDetectedProvider), isTrue);
      expect(container.read(appReadyProvider), isTrue);
    });

    test('crashDetectedProvider stays false when no crash marker', () async {
      expect(container.read(crashDetectedProvider), isFalse);

      await container.read(splashControllerProvider.future);

      expect(container.read(crashDetectedProvider), isFalse);
      expect(container.read(appReadyProvider), isTrue);
    });

    test('crash detection does not block appReady', () async {
      fakeStorage._store['crash_marker'] = 'true';

      await container.read(splashControllerProvider.future);

      // Both should be true — crash detection must not prevent readiness.
      expect(container.read(crashDetectedProvider), isTrue);
      expect(container.read(appReadyProvider), isTrue);
    });
  });
}
