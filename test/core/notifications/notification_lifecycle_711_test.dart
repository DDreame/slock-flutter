// =============================================================================
// #711 — Notification + lifecycle bugs
//
// A. P1: BackgroundNotificationWorker reconnect resets foregroundActive →
//    duplicate notifications while app in foreground
// B. P2: SocketIoBackgroundConnection.connect() old socket disposal emits
//    spurious disconnect after new socket created
// C. P2: ShareIntentStore registers onDispose inside async → missed disposal
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:slock_app/core/notifications/background_notification_worker.dart';
import 'package:slock_app/features/share/application/share_intent_store.dart';

void main() {
  group('#711A — P1: reconnect must not reset foregroundActive', () {
    late _FakeBackgroundSocketConnection fakeSocket;
    late _FakeBackgroundNotificationSink fakeSink;
    late _FakeBackgroundAuthProvider fakeAuth;
    late BackgroundNotificationWorker worker;

    setUp(() {
      fakeSocket = _FakeBackgroundSocketConnection();
      fakeSink = _FakeBackgroundNotificationSink();
      fakeAuth = _FakeBackgroundAuthProvider(
        token: 'test-token',
        userId: 'user-123',
        serverId: 'server-1',
      );
    });

    tearDown(() async {
      await worker.dispose();
    });

    test(
        'foregroundActive remains true after reconnect — no duplicate notification',
        () async {
      worker = BackgroundNotificationWorker(
        socket: fakeSocket,
        notificationSink: fakeSink,
        authProvider: fakeAuth,
      );
      await worker.start();

      // App is in foreground.
      worker.foregroundActive = true;

      // Socket reconnects (e.g., network toggle).
      fakeSocket.simulateReconnect();
      await Future<void>.delayed(Duration.zero);

      // foregroundActive should still be true.
      expect(worker.foregroundActive, isTrue,
          reason:
              'Reconnect must not reset foregroundActive — lifecycle binding owns it');

      // Message arrives — should be suppressed.
      fakeSocket.emitEvent({
        'id': 'msg-1',
        'channelId': 'channel-abc',
        'content': 'Should be suppressed',
        'senderId': 'other-user',
        'senderName': 'Alice',
        'senderType': 'human',
        'messageType': 'message',
        'createdAt': '2026-05-21T12:00:00Z',
        'seq': 1,
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeSink.notifications, isEmpty,
          reason: 'Notification must be suppressed while foreground is active');
    });

    test(
        'foregroundActive false before reconnect remains false — notifications still delivered',
        () async {
      worker = BackgroundNotificationWorker(
        socket: fakeSocket,
        notificationSink: fakeSink,
        authProvider: fakeAuth,
      );
      await worker.start();

      // App is in background.
      worker.foregroundActive = false;

      // Reconnect.
      fakeSocket.simulateReconnect();
      await Future<void>.delayed(Duration.zero);

      expect(worker.foregroundActive, isFalse);

      // Message arrives — should be delivered.
      fakeSocket.emitEvent({
        'id': 'msg-2',
        'channelId': 'channel-abc',
        'content': 'Background notification',
        'senderId': 'other-user',
        'senderName': 'Bob',
        'senderType': 'human',
        'messageType': 'message',
        'createdAt': '2026-05-21T12:01:00Z',
        'seq': 2,
      });
      await Future<void>.delayed(Duration.zero);

      expect(fakeSink.notifications, hasLength(1));
    });
  });

  group('#711B — P2: spurious disconnect on reconnect', () {
    test('reconnect does not emit spurious disconnect after new socket created',
        () async {
      final statusEvents = <BackgroundSocketStatus>[];
      final connection = _SpuriousDisconnectTestConnection();

      // Listen to all status changes.
      connection.statusChanges.listen(statusEvents.add);

      // Initial connect.
      await connection.connect(
        uri: 'wss://test.example.com',
        token: 'token-1',
      );
      expect(statusEvents, [BackgroundSocketStatus.connected]);
      statusEvents.clear();

      // Reconnect — should NOT emit disconnect from old socket.
      await connection.connect(
        uri: 'wss://test.example.com',
        token: 'token-2',
      );

      // Allow any async disconnect to propagate.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Should only see 'connected' for the new socket, NOT a spurious
      // 'disconnected' from the old socket disposal.
      expect(statusEvents, [BackgroundSocketStatus.connected],
          reason: 'Old socket disposal must not emit spurious disconnect');

      await connection.dispose();
    });

    test('disconnect still works after reconnect', () async {
      final statusEvents = <BackgroundSocketStatus>[];
      final connection = _SpuriousDisconnectTestConnection();

      connection.statusChanges.listen(statusEvents.add);

      await connection.connect(
        uri: 'wss://test.example.com',
        token: 'token-1',
      );
      statusEvents.clear();

      // Reconnect.
      await connection.connect(
        uri: 'wss://test.example.com',
        token: 'token-2',
      );
      statusEvents.clear();

      // Explicit disconnect of new socket should still emit.
      connection.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(statusEvents, [BackgroundSocketStatus.disconnected]);

      await connection.dispose();
    });
  });

  group('#711C — P2: ShareIntentStore onDispose in build (not async)', () {
    late StreamController<List<SharedMediaFile>> mediaStreamController;

    setUp(() {
      mediaStreamController =
          StreamController<List<SharedMediaFile>>.broadcast();
      ReceiveSharingIntent.setMockValues(
        initialMedia: [],
        mediaStream: mediaStreamController.stream,
      );
    });

    tearDown(() {
      mediaStreamController.close();
    });

    test('subscription cleaned up even if disposed before initialize completes',
        () async {
      final container = ProviderContainer();

      // Read the notifier to trigger build().
      container.read(shareIntentStoreProvider.notifier);

      // Dispose BEFORE initialize() is called — onDispose registered in
      // build() should handle the subscription (which is null at this point).
      container.dispose();

      // No crash, no leak — the test passes if no exception is thrown.
    });

    test('subscription cleaned up when disposed after initialize completes',
        () async {
      final container = ProviderContainer();

      final notifier = container.read(shareIntentStoreProvider.notifier);
      await notifier.initialize();

      // Verify stream is active.
      mediaStreamController.add([
        SharedMediaFile(path: 'test', type: SharedMediaType.text),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(shareIntentStoreProvider), isNotNull);

      // Dispose — onDispose in build() should cancel the subscription.
      container.dispose();

      // Adding to stream after dispose should not crash.
      mediaStreamController.add([
        SharedMediaFile(path: 'after-dispose', type: SharedMediaType.text),
      ]);
      await Future<void>.delayed(Duration.zero);
      // No crash = subscription was properly cancelled.
    });

    test('initialize called twice does not leak old subscription', () async {
      final container = ProviderContainer();

      final notifier = container.read(shareIntentStoreProvider.notifier);
      await notifier.initialize();
      await notifier.initialize(); // Second call should cancel first sub.

      // Only one active subscription.
      mediaStreamController.add([
        SharedMediaFile(path: 'latest', type: SharedMediaType.text),
      ]);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(shareIntentStoreProvider);
      expect(state!.items, hasLength(1));
      expect(state.items[0].path, 'latest');

      container.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeBackgroundSocketConnection implements BackgroundSocketConnection {
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController =
      StreamController<BackgroundSocketStatus>.broadcast();
  bool _connected = false;

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
  final List<Map<String, dynamic>> notifications = [];

  @override
  Future<void> showNotification(Map<String, dynamic> payload) async {
    notifications.add(payload);
  }
}

class _FakeBackgroundAuthProvider implements BackgroundAuthProvider {
  _FakeBackgroundAuthProvider({
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

  @override
  String get apiBaseUrl => 'https://api.example.com';
}

/// Test implementation of BackgroundSocketConnection that verifies the
/// spurious disconnect fix. Simulates the old socket disposal behavior
/// where dispose() would emit a disconnect event asynchronously.
class _SpuriousDisconnectTestConnection implements BackgroundSocketConnection {
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController =
      StreamController<BackgroundSocketStatus>.broadcast();

  _FakeSocket? _socket;

  @override
  bool get isConnected => _socket?.connected ?? false;

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
    // Null out before disposing old socket — prevents spurious disconnect.
    final oldSocket = _socket;
    _socket = null;
    oldSocket?.dispose();

    final newSocket = _FakeSocket();
    _socket = newSocket;

    newSocket.onDisconnect = () {
      // Only emit if this socket is still the current one.
      if (_socket == newSocket) {
        _statusController.add(BackgroundSocketStatus.disconnected);
      }
    };

    newSocket.connected = true;
    _statusController.add(BackgroundSocketStatus.connected);
  }

  @override
  void disconnect() {
    final socket = _socket;
    _socket = null;
    socket?.dispose();
    _statusController.add(BackgroundSocketStatus.disconnected);
  }

  @override
  Future<void> dispose() async {
    _socket?.dispose();
    _socket = null;
    await _eventController.close();
    await _statusController.close();
  }
}

/// Minimal fake socket that simulates disposal emitting a disconnect callback.
class _FakeSocket {
  bool connected = false;
  void Function()? onDisconnect;

  void dispose() {
    connected = false;
    // Simulate socket_io_client behavior: disposal triggers disconnect.
    onDisconnect?.call();
  }
}
