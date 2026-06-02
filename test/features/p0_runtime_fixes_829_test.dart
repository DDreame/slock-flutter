// =============================================================================
// #829 — P0 Runtime Bug Fixes (3 items)
//
// Bug 3: Stuck "Reconnecting..." — _onSocketError now triggers forceReconnect
// Bug 1: DM "resource not found" — metadata 404 no longer kills loadConversation
// Bug 2: Unread count race — inbox refresh suppressed for open conversation
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';

void main() {
  // ===========================================================================
  // Bug 3: _onSocketError triggers forceReconnect
  // ===========================================================================
  group('#829 Bug 3 — socket error triggers reconnect', () {
    test('RealtimeSocketError triggers forceReconnect (not stuck)', () async {
      final ingress = RealtimeReductionIngress();
      final socket = FakeRealtimeSocketClient();
      final container = ProviderContainer(
        overrides: [
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          realtimeSocketClientProvider.overrideWithValue(socket),
          realtimeBackoffSleeperProvider.overrideWithValue((_) async {}),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      final service = container.read(realtimeServiceProvider.notifier);
      await service.connect();
      socket.push(const RealtimeSocketConnected());
      await Future<void>.delayed(Duration.zero);

      // State should be connected.
      expect(
        container.read(realtimeServiceProvider).status,
        RealtimeConnectionStatus.connected,
      );

      final attempsBefore =
          container.read(realtimeServiceProvider).reconnectAttempts;

      // Simulate socket error.
      socket.push(RealtimeSocketError(Exception('network timeout')));
      // Wait for the unawaited forceReconnect to start and complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(realtimeServiceProvider);
      // Key assertion: reconnectAttempts increased — forceReconnect was
      // triggered, proving the state machine doesn't get stuck.
      expect(
        state.reconnectAttempts,
        greaterThan(attempsBefore),
        reason: 'Socket error must trigger a reconnect attempt',
      );
      // Socket should have disconnected and reconnected.
      expect(socket.disconnectCalls, greaterThanOrEqualTo(1));
      expect(socket.connectCalls, greaterThanOrEqualTo(2)); // initial + retry
    });
  });
}

// =============================================================================
// Test Doubles (reused from realtime_service_test.dart pattern)
// =============================================================================

class FakeRealtimeSocketClient implements RealtimeSocketClient {
  final StreamController<RealtimeSocketSignal> _signalsController =
      StreamController<RealtimeSocketSignal>.broadcast();
  final List<(String, Object?)> emittedEvents = <(String, Object?)>[];
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Stream<RealtimeSocketSignal> get signals => _signalsController.stream;

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {
    connectCalls += 1;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
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
