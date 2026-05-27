// ignore_for_file: prefer_const_constructors

// =============================================================================
// #685 — Realtime reconnection state machine unit test
//
// Scope: tests the RealtimeService state transitions observable at the
// Flutter layer. Exponential backoff timing (1s, 2s, 4s...) is delegated
// to socket.io's internal engine and is not testable from this layer.
//
// What these tests cover:
// 1. Error signal → status transitions to reconnecting, attempts increment
// 2. Multiple consecutive errors → attempts accumulate, status stays
//    reconnecting
// 3. Successful reconnect (Connected signal) → status resets to connected,
//    disconnect reason cleared, reconnectAttempts stays cumulative (tracks
//    total lifetime attempts for monitoring — socket.io resets its own
//    internal delay counter independently)
// 4. forceReconnect → increments attempts, records reason and timestamp
// 5. Disconnect signal → status transitions to disconnected with reason
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';

void main() {
  late FakeRealtimeSocketClient socket;
  late RealtimeReductionIngress ingress;
  late ProviderContainer container;
  late DateTime fakeNow;

  setUp(() async {
    fakeNow = DateTime(2026, 5, 21, 12, 0, 0);
    ingress = RealtimeReductionIngress();
    socket = FakeRealtimeSocketClient();

    container = ProviderContainer(
      overrides: [
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        realtimeSocketClientProvider.overrideWithValue(socket),
        realtimeClockProvider.overrideWithValue(() => fakeNow),
        realtimeBackoffSleeperProvider.overrideWithValue((_) async {}),
        realtimeWatchdogTimerFactoryProvider.overrideWithValue((_, __) {
          return _NoOpTimer();
        }),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await ingress.dispose();
  });

  RealtimeConnectionState readState() =>
      container.read(realtimeServiceProvider);

  group('#685 — Realtime reconnection state machine (Flutter-layer)', () {
    test('error signal increments reconnectAttempts', () async {
      final service = container.read(realtimeServiceProvider.notifier);
      await service.connect();

      // First error.
      socket.push(RealtimeSocketError('connection refused'));
      await Future<void>.delayed(Duration.zero);

      expect(readState().reconnectAttempts, 1);
      expect(readState().status, RealtimeConnectionStatus.reconnecting);
      expect(readState().disconnectReason, 'connection refused');
    });

    test('consecutive errors increment attempts cumulatively', () async {
      final service = container.read(realtimeServiceProvider.notifier);
      await service.connect();

      // Three consecutive errors — simulate repeated reconnection failures.
      socket.push(RealtimeSocketError('timeout #1'));
      await Future<void>.delayed(Duration.zero);
      expect(readState().reconnectAttempts, 1);

      socket.push(RealtimeSocketError('timeout #2'));
      await Future<void>.delayed(Duration.zero);
      expect(readState().reconnectAttempts, 2);

      socket.push(RealtimeSocketError('timeout #3'));
      await Future<void>.delayed(Duration.zero);
      expect(readState().reconnectAttempts, 3);

      // Status remains reconnecting throughout.
      expect(readState().status, RealtimeConnectionStatus.reconnecting);
      // Last error reason is tracked.
      expect(readState().disconnectReason, 'timeout #3');
    });

    test(
        'connected signal transitions status and clears reason (attempts stay cumulative)',
        () async {
      final service = container.read(realtimeServiceProvider.notifier);
      await service.connect();

      // Simulate errors.
      socket.push(RealtimeSocketError('network error'));
      await Future<void>.delayed(Duration.zero);
      socket.push(RealtimeSocketError('network error'));
      await Future<void>.delayed(Duration.zero);
      expect(readState().reconnectAttempts, 2);
      expect(readState().status, RealtimeConnectionStatus.reconnecting);

      // Successful reconnect.
      socket.push(const RealtimeSocketConnected());
      await Future<void>.delayed(Duration.zero);

      expect(
        readState().status,
        RealtimeConnectionStatus.connected,
        reason: 'Connected signal transitions status back to connected',
      );
      expect(
        readState().disconnectReason,
        isNull,
        reason: 'Connected signal clears disconnect reason',
      );
      expect(
        readState().lastConnectedAt,
        fakeNow,
        reason: 'Connected signal should record connection timestamp',
      );
      // reconnectAttempts is cumulative for the RealtimeService lifetime.
      // It tracks total attempts for monitoring/analytics. Socket.io manages
      // its own internal retry delay counter independently.
      expect(readState().reconnectAttempts, 2);
    });

    test('forceReconnect increments attempts and records reason', () async {
      final service = container.read(realtimeServiceProvider.notifier);
      await service.connect();
      socket.push(const RealtimeSocketConnected());
      await Future<void>.delayed(Duration.zero);

      expect(readState().reconnectAttempts, 0);
      expect(readState().status, RealtimeConnectionStatus.connected);

      // Force reconnect (e.g. watchdog detected stale connection).
      await service.forceReconnect(reason: 'heartbeat age 60s > 45s');
      await Future<void>.delayed(Duration.zero);

      expect(readState().reconnectAttempts, 1);
      expect(readState().status, RealtimeConnectionStatus.reconnecting);
      expect(readState().disconnectReason, 'heartbeat age 60s > 45s');
      expect(readState().lastForcedReconnectAt, fakeNow);
      // Verify socket was disconnected then reconnected.
      expect(socket.disconnectCalls, 1);
      expect(socket.connectCalls, 2); // initial + reconnect
    });

    test('disconnect signal updates status and records timestamp', () async {
      final service = container.read(realtimeServiceProvider.notifier);
      await service.connect();
      socket.push(const RealtimeSocketConnected());
      await Future<void>.delayed(Duration.zero);

      // Simulate server-initiated disconnect.
      socket.push(RealtimeSocketDisconnected(reason: 'server shutdown'));
      await Future<void>.delayed(Duration.zero);

      expect(readState().status, RealtimeConnectionStatus.disconnected);
      expect(readState().disconnectReason, 'server shutdown');
      expect(readState().lastDisconnectedAt, fakeNow);
    });

    test(
        'multi-cycle: error → connected → error → connected accumulates attempts',
        () async {
      final service = container.read(realtimeServiceProvider.notifier);
      await service.connect();

      // First error cycle.
      socket.push(RealtimeSocketError('fail 1'));
      await Future<void>.delayed(Duration.zero);
      expect(readState().reconnectAttempts, 1);

      socket.push(const RealtimeSocketConnected());
      await Future<void>.delayed(Duration.zero);
      expect(readState().status, RealtimeConnectionStatus.connected);

      // Second error cycle.
      socket.push(RealtimeSocketError('fail 2'));
      await Future<void>.delayed(Duration.zero);
      expect(readState().reconnectAttempts, 2);

      socket.push(const RealtimeSocketConnected());
      await Future<void>.delayed(Duration.zero);
      expect(readState().status, RealtimeConnectionStatus.connected);
      expect(readState().reconnectAttempts, 2);
      expect(readState().disconnectReason, isNull);
    });
  });
}

// =============================================================================
// Test doubles
// =============================================================================

class FakeRealtimeSocketClient implements RealtimeSocketClient {
  final StreamController<RealtimeSocketSignal> _signalsController =
      StreamController<RealtimeSocketSignal>.broadcast();
  final List<(String, Object?)> emittedEvents = <(String, Object?)>[];
  bool _isConnected = false;
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Stream<RealtimeSocketSignal> get signals => _signalsController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    connectCalls += 1;
    _isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    _isConnected = false;
  }

  @override
  void emit(String eventName, Object? payload) {
    emittedEvents.add((eventName, payload));
  }

  void push(RealtimeSocketSignal signal) {
    _signalsController.add(signal);
  }

  @override
  Future<void> dispose() async {
    await _signalsController.close();
  }
}

class _NoOpTimer implements Timer {
  @override
  bool get isActive => false;

  @override
  int get tick => 0;

  @override
  void cancel() {}
}
