// ignore_for_file: lines_longer_than_80_chars
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/background_notification_worker.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

// ---------------------------------------------------------------------------
// #562 Phase A — Silent Error → Diagnostic Telemetry (BackgroundWorker)
//
// Verifies that silent catch blocks in BackgroundNotificationWorker
// route errors to DiagnosticsCollector instead of swallowing silently.
//
// INV-TELEM-7: auth refresh failure → logged
// INV-TELEM-8: notification delivery failure → logged
//
// Phase A — all tests skip: true.
// ---------------------------------------------------------------------------

void main() {
  group('BackgroundNotificationWorker error telemetry', () {
    test(
      'auth refresh failure → logged (INV-TELEM-7)',
      skip: true,
      () async {
        // Setup: Create worker with authRefresher that throws.
        // Start the worker, then trigger a reconnect (which calls
        // _refreshAndReconnect → _authRefresher!()).
        //
        // Assert: DiagnosticsCollector has error entry with
        //   tag='BackgroundWorker', message contains 'auth'.
        //
        // Currently _refreshAndReconnect (line 244) has:
        //   catch (_) { // Fall through and use existing auth. }
        // Phase B will add diagnostics.error(...) in that catch.
        final diagnostics = DiagnosticsCollector();
        final fakeSocket = _FakeBackgroundSocketConnection();
        final fakeSink = _FakeBackgroundNotificationSink();
        final fakeAuth = _FakeBackgroundAuthProvider(
          token: 'test-token',
          userId: 'user-1',
          serverId: 'server-1',
        );

        final worker = BackgroundNotificationWorker(
          socket: fakeSocket,
          notificationSink: fakeSink,
          authProvider: fakeAuth,
          authRefresher: () async => throw Exception('Auth refresh failed'),
        );
        addTearDown(() async => worker.dispose());

        await worker.start();

        // Simulate disconnect → triggers reconnect → _refreshAndReconnect.
        fakeSocket.simulateDisconnect();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          diagnostics.entries.any(
            (e) =>
                e.tag == 'BackgroundWorker' &&
                e.level == DiagnosticsLevel.error &&
                e.message.toLowerCase().contains('auth'),
          ),
          isTrue,
          reason: 'Auth refresh failure must be logged to diagnostics',
        );
      },
    );

    test(
      'notification delivery failure → logged (INV-TELEM-8)',
      skip: true,
      () async {
        // Setup: Create worker with notificationSink that throws
        // a generic error (NOT BackgroundNotificationPermissionException).
        // Send a message event so _deliverNotification is called.
        //
        // Assert: DiagnosticsCollector has error entry with
        //   tag='BackgroundWorker', message contains 'notification'.
        //
        // Currently _deliverNotification (line 323) has:
        //   catch (_) { // Swallow other errors ... }
        // Phase B will add diagnostics.error(...) in that catch.
        final diagnostics = DiagnosticsCollector();
        final fakeSocket = _FakeBackgroundSocketConnection();
        final fakeSink = _ThrowingNotificationSink();
        final fakeAuth = _FakeBackgroundAuthProvider(
          token: 'test-token',
          userId: 'user-1',
          serverId: 'server-1',
        );

        final worker = BackgroundNotificationWorker(
          socket: fakeSocket,
          notificationSink: fakeSink,
          authProvider: fakeAuth,
        );
        addTearDown(() async => worker.dispose());

        await worker.start();

        // Send a message event to trigger _deliverNotification.
        fakeSocket.emitEvent({
          'id': 'msg-1',
          'channelId': 'channel-1',
          'content': 'Hello',
          'senderId': 'other-user',
          'senderName': 'Alice',
          'senderType': 'human',
          'messageType': 'message',
          'createdAt': '2026-05-18T00:00:00Z',
          'seq': 1,
        });
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          diagnostics.entries.any(
            (e) =>
                e.tag == 'BackgroundWorker' &&
                e.level == DiagnosticsLevel.error &&
                e.message.toLowerCase().contains('notification'),
          ),
          isTrue,
          reason: 'Notification delivery failure must be logged to diagnostics',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes — reuse patterns from background_notification_worker_test.dart
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

  void simulateDisconnect() {
    _connected = false;
    _statusController.add(BackgroundSocketStatus.disconnected);
  }
}

class _FakeBackgroundNotificationSink implements BackgroundNotificationSink {
  @override
  Future<void> showNotification(Map<String, dynamic> payload) async {}
}

/// Throws a generic error (not permission-related) on every call.
class _ThrowingNotificationSink implements BackgroundNotificationSink {
  @override
  Future<void> showNotification(Map<String, dynamic> payload) async {
    throw Exception('Notification delivery failed');
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
}
