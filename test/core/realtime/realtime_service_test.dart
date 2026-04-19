import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';

void main() {
  test('service emits resume payload using ingress lastSeqByScope on connect',
      () async {
    final ingress = RealtimeReductionIngress();
    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'message.created',
        scopeKey: 'server:1/channel:2',
        seq: 42,
        payload: const {'id': 'm1'},
        receivedAt: DateTime(2026),
      ),
    );

    final socket = FakeRealtimeSocketClient();
    final container = ProviderContainer(
      overrides: [
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        realtimeSocketClientProvider.overrideWithValue(socket),
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

    expect(socket.emittedEvents, hasLength(1));
    expect(socket.emittedEvents.single.$1, 'sync:resume');
    expect(
      socket.emittedEvents.single.$2,
      {
        'lastSeqByScope': {'server:1/channel:2': 42}
      },
    );
    expect(
      container.read(realtimeServiceProvider).status,
      RealtimeConnectionStatus.connected,
    );
  });

  test('service routes raw events through ingress and updates heartbeat clock',
      () async {
    final ingress = RealtimeReductionIngress();
    final socket = FakeRealtimeSocketClient();
    final container = ProviderContainer(
      overrides: [
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        realtimeSocketClientProvider.overrideWithValue(socket),
        realtimeClockProvider.overrideWithValue(() => DateTime(2026, 1, 1)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await ingress.dispose();
    });

    final acceptedEvents = <RealtimeEventEnvelope>[];
    final subscription = ingress.acceptedEvents.listen(acceptedEvents.add);
    addTearDown(subscription.cancel);

    final service = container.read(realtimeServiceProvider.notifier);
    await service.connect();
    socket.push(
      const RealtimeSocketRawEvent(eventName: 'heartbeat', payload: null),
    );
    socket.push(
      const RealtimeSocketRawEvent(
        eventName: 'message.created',
        payload: {'scopeKey': 'server:1/channel:2', 'seq': 7},
      ),
    );

    await Future<void>.delayed(Duration.zero);

    final state = container.read(realtimeServiceProvider);
    expect(state.lastHeartbeatAt, DateTime(2026, 1, 1));
    expect(state.lastAnyEventAt, DateTime(2026, 1, 1));
    expect(acceptedEvents, hasLength(1));
    expect(acceptedEvents.single.seq, 7);
  });

  test(
      'service uses injected watchdog timer to force reconnect on stale connection',
      () async {
    var now = DateTime(2026, 1, 1, 0, 0, 0);
    final ingress = RealtimeReductionIngress();
    final socket = FakeRealtimeSocketClient();
    void Function()? watchdogTick;

    final container = ProviderContainer(
      overrides: [
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        realtimeSocketClientProvider.overrideWithValue(socket),
        realtimeClockProvider.overrideWithValue(() => now),
        realtimeWatchdogConfigProvider.overrideWithValue(
          const RealtimeWatchdogConfig(
            interval: Duration(seconds: 5),
            heartbeatStaleAfter: Duration(seconds: 30),
            anyEventStaleAfter: Duration(seconds: 60),
          ),
        ),
        realtimeWatchdogTimerFactoryProvider.overrideWithValue((_, onTick) {
          watchdogTick = onTick;
          return FakePeriodicTimer();
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await ingress.dispose();
    });

    final service = container.read(realtimeServiceProvider.notifier);
    await service.connect();
    socket.push(const RealtimeSocketConnected());
    socket.push(
        const RealtimeSocketRawEvent(eventName: 'heartbeat', payload: null));

    await Future<void>.delayed(Duration.zero);

    now = now.add(const Duration(seconds: 65));
    watchdogTick?.call();

    await Future<void>.delayed(Duration.zero);

    final state = container.read(realtimeServiceProvider);
    expect(socket.connectCalls, 2);
    expect(socket.disconnectCalls, 1);
    expect(state.status, RealtimeConnectionStatus.reconnecting);
    expect(state.reconnectAttempts, 1);
    expect(state.disconnectReason, contains('heartbeat age'));
  });
}

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

class FakePeriodicTimer implements Timer {
  bool _isActive = true;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => 0;

  @override
  void cancel() {
    _isActive = false;
  }
}
