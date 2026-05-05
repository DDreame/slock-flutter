import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/background_notification_worker.dart';

void main() {
  group('BackgroundNotificationWorker', () {
    late FakeBackgroundSocketConnection fakeSocket;
    late FakeBackgroundNotificationSink fakeSink;
    late FakeBackgroundAuthProvider fakeAuth;
    late BackgroundNotificationWorker worker;

    setUp(() {
      fakeSocket = FakeBackgroundSocketConnection();
      fakeSink = FakeBackgroundNotificationSink();
      fakeAuth = FakeBackgroundAuthProvider(
        token: 'test-token',
        userId: 'user-123',
        serverId: 'server-1',
      );
    });

    tearDown(() {
      worker.dispose();
    });

    BackgroundNotificationWorker createWorker() {
      worker = BackgroundNotificationWorker(
        socket: fakeSocket,
        notificationSink: fakeSink,
        authProvider: fakeAuth,
      );
      return worker;
    }

    group('background state notification delivery', () {
      test('delivers notification for incoming message:new event', () async {
        createWorker();
        await worker.start();

        fakeSocket.emitEvent({
          'id': 'msg-1',
          'channelId': 'channel-abc',
          'content': 'Hello from background',
          'senderId': 'other-user',
          'senderName': 'Alice',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-05T01:00:00Z',
          'seq': 1,
        });
        await Future<void>.delayed(Duration.zero);

        expect(fakeSink.notifications, hasLength(1));
        expect(fakeSink.notifications.first['title'], 'Alice');
        expect(fakeSink.notifications.first['body'], 'Hello from background');
        expect(fakeSink.notifications.first['channelId'], 'channel-abc');
      });

      test('does not deliver notification for self-authored message', () async {
        createWorker();
        await worker.start();

        fakeSocket.emitEvent({
          'id': 'msg-2',
          'channelId': 'channel-abc',
          'content': 'My own message',
          'senderId': 'user-123', // Same as current user
          'senderName': 'Me',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-05T01:00:00Z',
          'seq': 2,
        });
        await Future<void>.delayed(Duration.zero);

        expect(fakeSink.notifications, isEmpty);
      });

      test('delivers notification with attachment fallback when content empty',
          () async {
        createWorker();
        await worker.start();

        fakeSocket.emitEvent({
          'id': 'msg-3',
          'channelId': 'channel-abc',
          'content': '',
          'senderId': 'other-user',
          'senderName': 'Bob',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-05T01:00:00Z',
          'seq': 3,
          'attachments': [
            {'id': 'att-1', 'filename': 'photo.png'}
          ],
        });
        await Future<void>.delayed(Duration.zero);

        expect(fakeSink.notifications, hasLength(1));
        expect(fakeSink.notifications.first['body'], '[Attachment]');
      });

      test('delivers multiple notifications for different channels', () async {
        createWorker();
        await worker.start();

        fakeSocket.emitEvent({
          'id': 'msg-4',
          'channelId': 'channel-1',
          'content': 'First',
          'senderId': 'user-a',
          'senderName': 'Alice',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-05T01:00:00Z',
          'seq': 1,
        });
        fakeSocket.emitEvent({
          'id': 'msg-5',
          'channelId': 'channel-2',
          'content': 'Second',
          'senderId': 'user-b',
          'senderName': 'Bob',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-05T01:01:00Z',
          'seq': 2,
        });
        await Future<void>.delayed(Duration.zero);

        expect(fakeSink.notifications, hasLength(2));
      });
    });

    group('service persistence across screen lock', () {
      test('worker remains active after start (simulates screen lock)',
          () async {
        createWorker();
        await worker.start();

        expect(worker.isActive, isTrue);
        expect(fakeSocket.isConnected, isTrue);
      });

      test('worker reconnects when socket disconnects unexpectedly', () async {
        createWorker();
        await worker.start();

        // Simulate unexpected disconnect.
        fakeSocket.simulateDisconnect();
        await Future<void>.delayed(Duration.zero);

        expect(worker.isActive, isTrue);
        // Should schedule reconnection.
        expect(fakeSocket.connectCallCount, greaterThan(1));
      });
    });

    group('reconnect after network change', () {
      test('reconnects after transient connection error', () async {
        createWorker();
        await worker.start();
        final initialConnectCount = fakeSocket.connectCallCount;

        // Simulate connection error (network change).
        fakeSocket.simulateConnectionError('Network unreachable');
        await Future<void>.delayed(
          const Duration(milliseconds: 50),
        );

        expect(fakeSocket.connectCallCount, greaterThan(initialConnectCount));
      });

      test('delivers notifications after reconnect', () async {
        createWorker();
        await worker.start();

        // Disconnect and reconnect.
        fakeSocket.simulateDisconnect();
        await Future<void>.delayed(Duration.zero);
        fakeSocket.simulateReconnect();

        fakeSocket.emitEvent({
          'id': 'msg-after-reconnect',
          'channelId': 'channel-abc',
          'content': 'After reconnect',
          'senderId': 'other-user',
          'senderName': 'Charlie',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-05T02:00:00Z',
          'seq': 10,
        });
        await Future<void>.delayed(Duration.zero);

        expect(fakeSink.notifications, hasLength(1));
        expect(fakeSink.notifications.first['body'], 'After reconnect');
      });
    });

    group('permission denial graceful handling', () {
      test('worker starts even when notification permission is denied',
          () async {
        fakeSink.permissionGranted = false;
        createWorker();
        await worker.start();

        expect(worker.isActive, isTrue);
        expect(fakeSocket.isConnected, isTrue);
      });

      test('swallows notification error when permission denied', () async {
        fakeSink.permissionGranted = false;
        fakeSink.throwOnNotify = true;
        createWorker();
        await worker.start();

        fakeSocket.emitEvent({
          'id': 'msg-denied',
          'channelId': 'channel-abc',
          'content': 'Should not crash',
          'senderId': 'other-user',
          'senderName': 'Dan',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-05T01:00:00Z',
          'seq': 1,
        });
        await Future<void>.delayed(Duration.zero);

        // Worker should still be active despite notification failure.
        expect(worker.isActive, isTrue);
        // Notification was attempted.
        expect(fakeSink.attemptCount, 1);
      });
    });

    group('diagnostics', () {
      test('reports connection status', () async {
        createWorker();
        await worker.start();

        final diagnostics = worker.diagnostics;
        expect(diagnostics.isServiceAlive, isTrue);
        expect(diagnostics.socketStatus, 'connected');
      });

      test('reports last event time after receiving event', () async {
        createWorker();
        await worker.start();

        expect(worker.diagnostics.lastEventTime, isNull);

        fakeSocket.emitEvent({
          'id': 'msg-diag',
          'channelId': 'channel-abc',
          'content': 'Diag test',
          'senderId': 'other-user',
          'senderName': 'Eve',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-05T01:00:00Z',
          'seq': 1,
        });
        await Future<void>.delayed(Duration.zero);

        expect(worker.diagnostics.lastEventTime, isNotNull);
      });

      test('reports last notification attempt time', () async {
        createWorker();
        await worker.start();

        expect(worker.diagnostics.lastNotificationAttempt, isNull);

        fakeSocket.emitEvent({
          'id': 'msg-notif',
          'channelId': 'channel-abc',
          'content': 'Notify test',
          'senderId': 'other-user',
          'senderName': 'Frank',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-05T01:00:00Z',
          'seq': 1,
        });
        await Future<void>.delayed(Duration.zero);

        expect(worker.diagnostics.lastNotificationAttempt, isNotNull);
      });

      test('reports permission failure status', () async {
        fakeSink.permissionGranted = false;
        fakeSink.throwOnNotify = true;
        createWorker();
        await worker.start();

        fakeSocket.emitEvent({
          'id': 'msg-perm',
          'channelId': 'channel-abc',
          'content': 'Perm test',
          'senderId': 'other-user',
          'senderName': 'Grace',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-05T01:00:00Z',
          'seq': 1,
        });
        await Future<void>.delayed(Duration.zero);

        expect(worker.diagnostics.lastPermissionFailure, isNotNull);
      });
    });

    group('auth handling', () {
      test('does not start when auth token is missing', () async {
        fakeAuth = FakeBackgroundAuthProvider(
          token: null,
          userId: 'user-123',
          serverId: 'server-1',
        );
        createWorker();
        await worker.start();

        expect(worker.isActive, isFalse);
        expect(fakeSocket.isConnected, isFalse);
      });

      test('stops when dispose is called', () async {
        createWorker();
        await worker.start();
        expect(worker.isActive, isTrue);

        worker.dispose();
        expect(worker.isActive, isFalse);
        expect(fakeSocket.isConnected, isFalse);
      });
    });

    group('auth refresh', () {
      test('refreshAuth reloads credentials and reconnects', () async {
        final refreshedAuth = FakeBackgroundAuthProvider(
          token: 'refreshed-token',
          userId: 'user-123',
          serverId: 'server-2',
        );

        worker = BackgroundNotificationWorker(
          socket: fakeSocket,
          notificationSink: fakeSink,
          authProvider: fakeAuth,
          authRefresher: () async => refreshedAuth,
        );
        await worker.start();

        final connectCountBefore = fakeSocket.connectCallCount;
        await worker.refreshAuth();

        // Should have reconnected with fresh credentials.
        expect(fakeSocket.connectCallCount, greaterThan(connectCountBefore));
        expect(fakeSocket.lastConnectToken, 'refreshed-token');
        expect(fakeSocket.lastConnectServerId, 'server-2');
      });

      test('reconnect uses refreshed auth when authRefresher provided',
          () async {
        final refreshedAuth = FakeBackgroundAuthProvider(
          token: 'new-token-after-refresh',
          userId: 'user-123',
          serverId: 'server-new',
        );

        worker = BackgroundNotificationWorker(
          socket: fakeSocket,
          notificationSink: fakeSink,
          authProvider: fakeAuth,
          authRefresher: () async => refreshedAuth,
        );
        await worker.start();

        // Simulate disconnect — should trigger reconnect with refreshed auth.
        fakeSocket.simulateDisconnect();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(fakeSocket.lastConnectToken, 'new-token-after-refresh');
        expect(fakeSocket.lastConnectServerId, 'server-new');
      });
    });

    group('foreground active suppression', () {
      test('suppresses notification when foreground is active', () async {
        createWorker();
        await worker.start();

        worker.foregroundActive = true;

        fakeSocket.emitEvent({
          'id': 'msg-fg',
          'channelId': 'channel-abc',
          'content': 'Should be suppressed',
          'senderId': 'other-user',
          'senderName': 'Alice',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-05T01:00:00Z',
          'seq': 1,
        });
        await Future<void>.delayed(Duration.zero);

        expect(fakeSink.notifications, isEmpty);
      });

      test('delivers notification when foreground becomes inactive', () async {
        createWorker();
        await worker.start();

        // Start in foreground-active mode.
        worker.foregroundActive = true;

        fakeSocket.emitEvent({
          'id': 'msg-fg-1',
          'channelId': 'channel-abc',
          'content': 'Suppressed',
          'senderId': 'other-user',
          'senderName': 'Alice',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-05T01:00:00Z',
          'seq': 1,
        });
        await Future<void>.delayed(Duration.zero);
        expect(fakeSink.notifications, isEmpty);

        // App goes to background.
        worker.foregroundActive = false;

        fakeSocket.emitEvent({
          'id': 'msg-bg-1',
          'channelId': 'channel-abc',
          'content': 'Should deliver',
          'senderId': 'other-user',
          'senderName': 'Bob',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-05T01:01:00Z',
          'seq': 2,
        });
        await Future<void>.delayed(Duration.zero);

        expect(fakeSink.notifications, hasLength(1));
        expect(fakeSink.notifications.first['body'], 'Should deliver');
      });
    });
  });
}

// -- Test doubles -----------------------------------------------------------

class FakeBackgroundSocketConnection implements BackgroundSocketConnection {
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController =
      StreamController<BackgroundSocketStatus>.broadcast();
  bool _connected = false;
  int _connectCallCount = 0;
  String? _lastConnectToken;
  String? _lastConnectServerId;

  int get connectCallCount => _connectCallCount;
  String? get lastConnectToken => _lastConnectToken;
  String? get lastConnectServerId => _lastConnectServerId;

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
    _connectCallCount++;
    _lastConnectToken = token;
    _lastConnectServerId = serverId;
    _connected = true;
    _statusController.add(BackgroundSocketStatus.connected);
  }

  @override
  void disconnect() {
    _connected = false;
    _statusController.add(BackgroundSocketStatus.disconnected);
  }

  void emitEvent(Map<String, dynamic> payload) {
    _eventController.add(payload);
  }

  void simulateDisconnect() {
    _connected = false;
    _statusController.add(BackgroundSocketStatus.disconnected);
  }

  void simulateConnectionError(String message) {
    _statusController.add(BackgroundSocketStatus.error);
  }

  void simulateReconnect() {
    _connected = true;
    _statusController.add(BackgroundSocketStatus.connected);
  }
}

class FakeBackgroundNotificationSink implements BackgroundNotificationSink {
  final List<Map<String, dynamic>> notifications = [];
  bool permissionGranted = true;
  bool throwOnNotify = false;
  int attemptCount = 0;

  @override
  Future<void> showNotification(Map<String, dynamic> payload) async {
    attemptCount++;
    if (throwOnNotify) {
      throw const BackgroundNotificationPermissionException(
        'POST_NOTIFICATIONS permission denied',
      );
    }
    notifications.add(payload);
  }
}

class FakeBackgroundAuthProvider implements BackgroundAuthProvider {
  FakeBackgroundAuthProvider({
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
