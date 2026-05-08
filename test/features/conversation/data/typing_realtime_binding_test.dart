import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/realtime/realtime_event_envelope.dart';
import 'package:slock_app/core/realtime/realtime_reduction_ingress.dart';
import 'package:slock_app/core/realtime/realtime_socket_client.dart';
import 'package:slock_app/features/conversation/application/typing_indicator_store.dart';
import 'package:slock_app/features/conversation/data/typing_realtime_binding.dart';

void main() {
  late ProviderContainer container;
  late TypingIndicatorStore store;
  late RealtimeReductionIngress ingress;
  late _FakeSocketClient socketClient;
  late TypingRealtimeBinding binding;
  ProviderSubscription<TypingIndicatorState>? sub;

  setUp(() {
    container = ProviderContainer();
    sub = container.listen(typingIndicatorStoreProvider, (_, __) {});
    store = container.read(typingIndicatorStoreProvider.notifier);
    ingress = RealtimeReductionIngress();
    socketClient = _FakeSocketClient();
    binding = TypingRealtimeBinding(
      scopeKey: 'server:s1/channel:ch1',
      store: store,
      ingress: ingress,
      socketClient: socketClient,
      currentUserId: 'current-user',
    );
  });

  tearDown(() {
    binding.dispose();
    sub?.close();
    container.dispose();
  });

  group('TypingRealtimeBinding — receive', () {
    test('adds typer when typing:start event received for matching scope',
        () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kTypingStartEvent,
        scopeKey: 'server:s1/channel:ch1',
        receivedAt: DateTime.now(),
        payload: {
          'scopeKey': 'server:s1/channel:ch1',
          'userId': 'user-2',
          'displayName': 'Bob',
        },
      ));

      // Allow the stream listener to process.
      await Future<void>.delayed(Duration.zero);

      final state = container.read(typingIndicatorStoreProvider);
      expect(state.activeTypers, hasLength(1));
      expect(state.activeTypers.first.userId, 'user-2');
      expect(state.activeTypers.first.displayName, 'Bob');
    });

    test('ignores typing events from different scope', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kTypingStartEvent,
        scopeKey: 'server:s1/channel:other',
        receivedAt: DateTime.now(),
        payload: {
          'scopeKey': 'server:s1/channel:other',
          'userId': 'user-2',
          'displayName': 'Bob',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(typingIndicatorStoreProvider);
      expect(state.activeTypers, isEmpty);
    });

    test('ignores typing events from current user', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kTypingStartEvent,
        scopeKey: 'server:s1/channel:ch1',
        receivedAt: DateTime.now(),
        payload: {
          'scopeKey': 'server:s1/channel:ch1',
          'userId': 'current-user',
          'displayName': 'Me',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(typingIndicatorStoreProvider);
      expect(state.activeTypers, isEmpty);
    });

    test('ignores non-typing events', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'server:s1/channel:ch1',
        receivedAt: DateTime.now(),
        payload: {
          'scopeKey': 'server:s1/channel:ch1',
          'userId': 'user-2',
          'displayName': 'Bob',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(typingIndicatorStoreProvider);
      expect(state.activeTypers, isEmpty);
    });

    test('uses userId as fallback when displayName is null', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kTypingStartEvent,
        scopeKey: 'server:s1/channel:ch1',
        receivedAt: DateTime.now(),
        payload: {
          'scopeKey': 'server:s1/channel:ch1',
          'userId': 'user-2',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(typingIndicatorStoreProvider);
      expect(state.activeTypers.first.displayName, 'user-2');
    });
  });

  group('TypingRealtimeBinding — emit', () {
    test('emitTyping sends typing:start event to server', () {
      binding.bind();
      binding.emitTyping();

      expect(socketClient.emittedEvents, hasLength(1));
      expect(socketClient.emittedEvents.first.eventName, kTypingStartEvent);
      final payload =
          socketClient.emittedEvents.first.payload as Map<String, dynamic>;
      expect(payload['scopeKey'], 'server:s1/channel:ch1');
    });

    test('emitTyping throttles — second call within cooldown is suppressed',
        () {
      binding.bind();
      binding.emitTyping();
      binding.emitTyping(); // Should be throttled.

      expect(socketClient.emittedEvents, hasLength(1));
    });
  });

  group('TypingRealtimeBinding — dispose', () {
    test('dispose clears typers and stops listening', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kTypingStartEvent,
        scopeKey: 'server:s1/channel:ch1',
        receivedAt: DateTime.now(),
        payload: {
          'scopeKey': 'server:s1/channel:ch1',
          'userId': 'user-2',
          'displayName': 'Bob',
        },
      ));

      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(typingIndicatorStoreProvider).activeTypers,
        hasLength(1),
      );

      binding.dispose();

      expect(
        container.read(typingIndicatorStoreProvider).activeTypers,
        isEmpty,
      );
    });
  });
}

class _EmittedEvent {
  _EmittedEvent(this.eventName, this.payload);

  final String eventName;
  final Object? payload;
}

class _FakeSocketClient implements RealtimeSocketClient {
  final List<_EmittedEvent> emittedEvents = [];

  @override
  Stream<RealtimeSocketSignal> get signals => const Stream.empty();

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void emit(String eventName, Object? payload) {
    emittedEvents.add(_EmittedEvent(eventName, payload));
  }

  @override
  Future<void> dispose() async {}
}
