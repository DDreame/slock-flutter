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
// Phase B seam: BackgroundNotificationWorker will accept an optional
// `DiagnosticsCollector? diagnostics` constructor parameter. In Phase B:
//   1. Add field: `final DiagnosticsCollector? _diagnostics;`
//   2. _refreshAndReconnect catch (line 244):
//        `_diagnostics?.error('BackgroundWorker', 'auth refresh failed: $e');`
//   3. _deliverNotification generic catch (line 323):
//        `_diagnostics?.error('BackgroundWorker', 'notification delivery failed: $e');`
//   4. Update _createWorker below to forward the parameter.
//
// Phase A — all tests skip: true.
// ---------------------------------------------------------------------------

void main() {
  group('BackgroundNotificationWorker error telemetry', () {
    test(
      'auth refresh failure → logged (INV-TELEM-7)',
      skip: true,
      () async {
        // Setup: Worker with authRefresher that throws.
        // Start the worker, then trigger disconnect → _refreshAndReconnect.
        //
        // Phase B wires diagnostics into the worker constructor (see
        // _createWorker helper). After that, the catch block in
        // _refreshAndReconnect calls diagnostics.error(...).
        final diagnostics = DiagnosticsCollector();
        final fakeSocket = _FakeBackgroundSocketConnection();

        final worker = _createWorker(
          socket: fakeSocket,
          sink: _FakeBackgroundNotificationSink(),
          auth: _FakeBackgroundAuthProvider(
            token: 'test-token',
            userId: 'user-1',
            serverId: 'server-1',
          ),
          authRefresher: () async => throw Exception('Auth refresh failed'),
          diagnostics: diagnostics,
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
        // Setup: Worker with notificationSink that throws a generic error
        // (NOT BackgroundNotificationPermissionException).
        //
        // Phase B wires diagnostics into the worker constructor (see
        // _createWorker helper). After that, the generic catch block in
        // _deliverNotification calls diagnostics.error(...).
        final diagnostics = DiagnosticsCollector();
        final fakeSocket = _FakeBackgroundSocketConnection();

        final worker = _createWorker(
          socket: fakeSocket,
          sink: _ThrowingNotificationSink(),
          auth: _FakeBackgroundAuthProvider(
            token: 'test-token',
            userId: 'user-1',
            serverId: 'server-1',
          ),
          diagnostics: diagnostics,
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
// Worker factory — Phase B injection seam
// ---------------------------------------------------------------------------

/// Creates a [BackgroundNotificationWorker] with diagnostic telemetry.
///
/// Phase B change: forward [diagnostics] to the worker constructor once it
/// accepts the optional parameter:
///
/// ```dart
/// return BackgroundNotificationWorker(
///   socket: socket,
///   notificationSink: sink,
///   authProvider: auth,
///   authRefresher: authRefresher,
///   diagnostics: diagnostics,  // ← Phase B addition
/// );
/// ```
BackgroundNotificationWorker _createWorker({
  required _FakeBackgroundSocketConnection socket,
  required BackgroundNotificationSink sink,
  required BackgroundAuthProvider auth,
  BackgroundAuthRefresher? authRefresher,
  DiagnosticsCollector? diagnostics,
}) {
  // Phase B: forward diagnostics to the worker constructor.
  return BackgroundNotificationWorker(
    socket: socket,
    notificationSink: sink,
    authProvider: auth,
    authRefresher: authRefresher,
    diagnostics: diagnostics,
  );
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
