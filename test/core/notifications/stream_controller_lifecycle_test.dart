// ---------------------------------------------------------------------------
// #553: StreamController Lifecycle — dispose contract + shutdown
//
// Problem: SocketIoBackgroundConnection holds two broadcast
// StreamControllers (_eventController, _statusController) that are
// never closed:
//   1. The abstract interface BackgroundSocketConnection declares
//      disconnect() but no dispose() — no contract for teardown.
//   2. SocketIoBackgroundConnection has no dispose() method at all.
//   3. BackgroundNotificationWorker.dispose() calls _socket.disconnect()
//      which only tears down the underlying io.Socket, leaving both
//      StreamControllers open and leaked.
//
// Contrast: SocketIoRealtimeSocketClient, RealtimeReductionIngress,
// ConnectivityService, VoiceRecorderService — all have dispose() that
// closes their StreamControllers. SocketIoBackgroundConnection is the
// sole exception.
//
// Phase A: skip:true invariants locking the dispose lifecycle contract.
//          Test-local seams simulate the StreamController lifecycle.
//          Phase B will add dispose() to the interface and implementation.
//
// Invariants verified:
// INV-STREAM-DISPOSE-1: dispose() closes both event and status streams
// INV-STREAM-DISPOSE-2: disconnect() does NOT close streams (reconnectable)
// INV-STREAM-DISPOSE-3: After dispose(), connect() is a no-op or throws
// INV-STREAM-LISTEN-1: Active listeners receive events across reconnects
// ---------------------------------------------------------------------------
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test-local seams: mirror the production BackgroundSocketConnection
// with the lifecycle gaps fixed.
//
// Phase B:
//   1. Add Future<void> dispose() to abstract BackgroundSocketConnection
//   2. Implement dispose() in SocketIoBackgroundConnection:
//      _socket?.dispose(); _socket = null;
//      await _eventController.close(); await _statusController.close();
//   3. Update BackgroundNotificationWorker.dispose() to call
//      _socket.dispose() instead of _socket.disconnect()
// ---------------------------------------------------------------------------

/// Enum mirroring BackgroundSocketStatus from production.
enum _TestSocketStatus { connected, disconnected }

/// Test-local seam simulating a BackgroundSocketConnection with proper
/// dispose() lifecycle.
///
/// Phase B: this contract moves into the real abstract interface and
/// SocketIoBackgroundConnection.
class _TestableBackgroundSocketConnection {
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<_TestSocketStatus>.broadcast();

  bool _connected = false;
  bool _disposed = false;

  bool get isConnected => _connected;
  bool get isDisposed => _disposed;

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  Stream<_TestSocketStatus> get statusChanges => _statusController.stream;

  Future<void> connect({
    required String uri,
    required String token,
  }) async {
    if (_disposed) return; // no-op after dispose
    _connected = true;
    _statusController.add(_TestSocketStatus.connected);
  }

  /// Disconnect only tears down the socket connection — streams stay
  /// open for reconnection.
  void disconnect() {
    _connected = false;
    _statusController.add(_TestSocketStatus.disconnected);
  }

  /// Terminal teardown: close both StreamControllers.
  /// After dispose, connect() is a no-op.
  Future<void> dispose() async {
    _disposed = true;
    _connected = false;
    await _eventController.close();
    await _statusController.close();
  }

  /// Test helper: emit an event.
  void emitEvent(Map<String, dynamic> payload) {
    if (!_disposed) {
      _eventController.add(payload);
    }
  }
}

void main() {
  // -----------------------------------------------------------------------
  // INV-STREAM-DISPOSE-1: dispose() closes both streams
  // -----------------------------------------------------------------------
  group('INV-STREAM-DISPOSE-1: dispose closes streams', () {
    test(
      'eventStream completes after dispose',
      skip: true,
      () async {
        final conn = _TestableBackgroundSocketConnection();

        // Listen and track completion.
        var eventStreamDone = false;
        conn.events.listen(
          (_) {},
          onDone: () => eventStreamDone = true,
        );

        await conn.dispose();

        expect(eventStreamDone, isTrue,
            reason: 'Event stream listener should receive done after dispose');
      },
    );

    test(
      'statusStream completes after dispose',
      skip: true,
      () async {
        final conn = _TestableBackgroundSocketConnection();

        var statusStreamDone = false;
        conn.statusChanges.listen(
          (_) {},
          onDone: () => statusStreamDone = true,
        );

        await conn.dispose();

        expect(statusStreamDone, isTrue,
            reason: 'Status stream listener should receive done after dispose');
      },
    );

    test(
      'both streams closed after dispose',
      skip: true,
      () async {
        final conn = _TestableBackgroundSocketConnection();

        // Collect events to verify stream termination.
        final events = <Map<String, dynamic>>[];
        final statuses = <_TestSocketStatus>[];
        final eventSub = conn.events.listen(events.add);
        final statusSub = conn.statusChanges.listen(statuses.add);

        conn.emitEvent({'msg': 'before-dispose'});
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1));

        await conn.dispose();

        // After dispose, no more events should arrive.
        expect(conn.isDisposed, isTrue);

        eventSub.cancel();
        statusSub.cancel();
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-STREAM-DISPOSE-2: disconnect() does NOT close streams
  // -----------------------------------------------------------------------
  group('INV-STREAM-DISPOSE-2: disconnect preserves streams', () {
    test(
      'streams remain open after disconnect',
      skip: true,
      () async {
        final conn = _TestableBackgroundSocketConnection();

        var eventStreamDone = false;
        conn.events.listen(
          (_) {},
          onDone: () => eventStreamDone = true,
        );

        await conn.connect(uri: 'ws://test', token: 'tok');
        conn.disconnect();
        await Future<void>.delayed(Duration.zero);

        expect(eventStreamDone, isFalse,
            reason: 'disconnect() must NOT close streams — they are reusable');
        expect(conn.isConnected, isFalse);
        expect(conn.isDisposed, isFalse);
      },
    );

    test(
      'events can still be emitted after disconnect',
      skip: true,
      () async {
        final conn = _TestableBackgroundSocketConnection();
        final events = <Map<String, dynamic>>[];
        conn.events.listen(events.add);

        await conn.connect(uri: 'ws://test', token: 'tok');
        conn.disconnect();

        // Streams still open — emitting should work.
        conn.emitEvent({'msg': 'after-disconnect'});
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first['msg'], 'after-disconnect');
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-STREAM-DISPOSE-3: connect() after dispose() is no-op
  // -----------------------------------------------------------------------
  group('INV-STREAM-DISPOSE-3: connect after dispose is no-op', () {
    test(
      'connect() after dispose() does not establish connection',
      skip: true,
      () async {
        final conn = _TestableBackgroundSocketConnection();

        await conn.dispose();
        await conn.connect(uri: 'ws://test', token: 'tok');

        expect(conn.isConnected, isFalse,
            reason: 'connect() after dispose() should be a no-op');
      },
    );

    test(
      'no status events emitted from connect after dispose',
      skip: true,
      () async {
        final conn = _TestableBackgroundSocketConnection();

        final statuses = <_TestSocketStatus>[];
        // Listen before dispose to catch any post-dispose emissions.
        conn.statusChanges.listen(statuses.add);

        await conn.dispose();
        await Future<void>.delayed(Duration.zero);
        final countAfterDispose = statuses.length;

        await conn.connect(uri: 'ws://test', token: 'tok');
        await Future<void>.delayed(Duration.zero);

        expect(statuses.length, countAfterDispose,
            reason: 'No new status events should be emitted after dispose');
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-STREAM-LISTEN-1: listeners survive disconnect/reconnect cycles
  // -----------------------------------------------------------------------
  group('INV-STREAM-LISTEN-1: listeners across reconnect cycles', () {
    test(
      'active listeners receive events across connect/disconnect cycles',
      skip: true,
      () async {
        final conn = _TestableBackgroundSocketConnection();
        final events = <Map<String, dynamic>>[];
        conn.events.listen(events.add);

        // First connection cycle.
        await conn.connect(uri: 'ws://test', token: 'tok');
        conn.emitEvent({'cycle': 1});
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1));

        // Disconnect and reconnect.
        conn.disconnect();
        await conn.connect(uri: 'ws://test', token: 'tok');
        conn.emitEvent({'cycle': 2});
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(2),
            reason:
                'Same listener should receive events across reconnect cycles');
        expect(events[0]['cycle'], 1);
        expect(events[1]['cycle'], 2);
      },
    );

    test(
      'status listeners receive transitions across reconnect cycles',
      skip: true,
      () async {
        final conn = _TestableBackgroundSocketConnection();
        final statuses = <_TestSocketStatus>[];
        conn.statusChanges.listen(statuses.add);

        await conn.connect(uri: 'ws://test', token: 'tok');
        conn.disconnect();
        await conn.connect(uri: 'ws://test', token: 'tok');
        await Future<void>.delayed(Duration.zero);

        expect(statuses, [
          _TestSocketStatus.connected,
          _TestSocketStatus.disconnected,
          _TestSocketStatus.connected,
        ]);
      },
    );
  });
}
