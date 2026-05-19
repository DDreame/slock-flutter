import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/notifications/background_notification_worker.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/foreground_service_lifecycle_binding.dart';
import 'package:slock_app/core/notifications/foreground_service_manager.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// Phase A — all tests skip: true.
//
// INV-NOTIF-RELIABLE-1: foregroundActive resets on reconnection unless the
// foreground bridge explicitly re-asserts foreground-active=true.
void main() {
  group('Background notification reliability hardening', () {
    late _FakeBackgroundSocketConnection socket;
    late _FakeBackgroundNotificationSink sink;
    late _FakeBackgroundAuthProvider auth;
    late BackgroundNotificationWorker worker;

    setUp(() {
      socket = _FakeBackgroundSocketConnection();
      sink = _FakeBackgroundNotificationSink();
      auth = const _FakeBackgroundAuthProvider(
        token: 'token-1',
        userId: 'user-1',
        serverId: 'server-1',
      );
      worker = BackgroundNotificationWorker(
        socket: socket,
        notificationSink: sink,
        authProvider: auth,
      );
    });

    tearDown(() async {
      await worker.dispose();
    });

    test('connected status clears stale foregroundActive before delivery '
        '(INV-NOTIF-RELIABLE-1)', () async {
      await worker.start();
      worker.foregroundActive = true;

      socket.simulateReconnect();
      await Future<void>.delayed(const Duration(milliseconds: 550));

      expect(
        worker.foregroundActive,
        isFalse,
        reason:
            'Reconnect must clear stale foreground-active suppression '
            'unless the foreground bridge re-asserts true.',
      );

      socket.emitEvent({
        'id': 'msg-after-reconnect',
        'channelId': 'channel-1',
        'content': 'Background delivery recovered',
        'senderId': 'other-user',
        'senderName': 'Alice',
        'messageType': 'message',
      });
      await Future<void>.delayed(Duration.zero);

      expect(sink.notifications, hasLength(1));
    }, skip: true);

    test('backgroundWorkerDiagnosticsProvider exposes service/auth/foreground '
        'state and last event time', () async {
      final manager = _FakeForegroundServiceManager(
        running: true,
        diagnostics: {
          'isServiceAlive': true,
          'socketStatus': 'connected',
          'authStatus': 'authenticated',
          'foregroundActive': false,
          'lastEventTime': '2026-05-19T06:55:00.000Z',
        },
      );
      final container = ProviderContainer(
        overrides: [
          foregroundServiceManagerProvider.overrideWithValue(manager),
        ],
      );
      addTearDown(container.dispose);

      final diagnostics = await container.read(
        backgroundWorkerDiagnosticsProvider.future,
      );

      expect(diagnostics, isNotNull);
      expect(diagnostics!['isServiceAlive'], isTrue);
      expect(diagnostics['socketStatus'], 'connected');
      expect(diagnostics['authStatus'], 'authenticated');
      expect(diagnostics['foregroundActive'], isFalse);
      expect(diagnostics['lastEventTime'], isNotNull);
    }, skip: true);

    testWidgets('foreground service restarts when unexpectedly stopped while '
        'authenticated', (tester) async {
      final manager = _FakeForegroundServiceManager(running: true);
      final notificationStore = _FakeNotificationStore();
      final container = ProviderContainer(
        overrides: [
          appReadyProvider.overrideWith((ref) => true),
          foregroundServiceManagerProvider.overrideWithValue(manager),
          notificationStoreProvider.overrideWith(() => notificationStore),
          sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      container.read(foregroundServiceLifecycleBindingProvider);
      await tester.pump();
      await tester.pump();
      final startsAfterInitialSync = manager.startServiceCount;

      manager.running = false;
      notificationStore.setLifecycleStatus(AppLifecycleStatus.paused);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        manager.startServiceCount,
        greaterThan(startsAfterInitialSync),
        reason:
            'Authenticated service binding must detect an unexpected '
            'stop and restart the foreground service.',
      );
    }, skip: true);
  });
}

class _FakeBackgroundSocketConnection implements BackgroundSocketConnection {
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController =
      StreamController<BackgroundSocketStatus>.broadcast();
  var _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  @override
  Stream<BackgroundSocketStatus> get statusChanges => _statusController.stream;

  @override
  Future<void> connect({
    required String uri,
    required String token,
    String? serverId,
  }) async {
    _connected = true;
    _statusController.add(BackgroundSocketStatus.connected);
  }

  @override
  void disconnect() {
    _connected = false;
    _statusController.add(BackgroundSocketStatus.disconnected);
  }

  @override
  Future<void> dispose() async {
    _connected = false;
    await _eventController.close();
    await _statusController.close();
  }

  void emitEvent(Map<String, dynamic> payload) {
    _eventController.add(payload);
  }

  void simulateReconnect() {
    _connected = true;
    _statusController.add(BackgroundSocketStatus.connected);
  }
}

class _FakeBackgroundNotificationSink implements BackgroundNotificationSink {
  final notifications = <Map<String, dynamic>>[];

  @override
  Future<void> showNotification(Map<String, dynamic> payload) async {
    notifications.add(payload);
  }
}

class _FakeBackgroundAuthProvider implements BackgroundAuthProvider {
  const _FakeBackgroundAuthProvider({
    required this.token,
    required this.userId,
    required this.serverId,
  });

  @override
  final String? token;

  @override
  final String? userId;

  @override
  final String? serverId;

  @override
  String get realtimeUrl => 'wss://realtime.example.com';
}

class _FakeForegroundServiceManager implements ForegroundServiceManager {
  _FakeForegroundServiceManager({
    required this.running,
    Map<String, dynamic>? diagnostics,
  }) : diagnostics = diagnostics ?? <String, dynamic>{};

  bool running;
  final Map<String, dynamic> diagnostics;
  var startServiceCount = 0;
  var stopServiceCount = 0;
  var authFlagUpdates = <bool>[];
  var foregroundActiveUpdates = <bool>[];

  @override
  Future<void> startService() async {
    startServiceCount++;
    running = true;
  }

  @override
  Future<void> stopService() async {
    stopServiceCount++;
    running = false;
  }

  @override
  Future<bool> get isRunning async => running;

  @override
  Future<void> setAuthFlag(bool authenticated) async {
    authFlagUpdates.add(authenticated);
  }

  @override
  Future<void> refreshWorkerAuth() async {}

  @override
  Future<void> setWorkerForegroundActive(bool active) async {
    foregroundActiveUpdates.add(active);
  }

  @override
  Future<Map<String, dynamic>?> getWorkerDiagnostics() async => diagnostics;
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
    status: AuthStatus.authenticated,
    userId: 'user-1',
    token: 'token-1',
  );
}

class _FakeNotificationStore extends NotificationStore {
  @override
  NotificationState build() =>
      const NotificationState(lifecycleStatus: AppLifecycleStatus.resumed);

  void setLifecycleStatus(AppLifecycleStatus status) {
    state = state.copyWith(lifecycleStatus: status);
  }
}
