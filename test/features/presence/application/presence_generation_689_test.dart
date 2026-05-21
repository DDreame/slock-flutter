// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

// =============================================================================
// #689 — PresenceState generation counter + dispose flash fix
//
// Tests:
// 1. Generation counter: O(1) equality — same generation == equal, different
//    generation == not equal (even with same statuses map content).
// 2. Each mutation increments generation (setOnline, setIdle, setOffline,
//    setPresence, setOnlineList, clearAll).
// 3. Idempotent mutations do NOT increment generation.
// 4. Dispose flash: disposing the realtime binding does NOT produce a transient
//    empty-state notification (no clearAll call).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/realtime/realtime_event_envelope.dart';
import 'package:slock_app/core/realtime/realtime_reduction_ingress.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';
import 'package:slock_app/features/presence/data/presence_realtime_binding.dart';

void main() {
  group('#689 — PresenceState generation counter equality', () {
    late ProviderContainer container;
    late ProviderSubscription<PresenceState> sub;

    setUp(() {
      container = ProviderContainer();
      sub = container.listen(presenceStoreProvider, (_, __) {});
    });

    tearDown(() {
      sub.close();
      container.dispose();
    });

    test('initial state has generation 0', () {
      final state = container.read(presenceStoreProvider);
      expect(state.generation, 0);
    });

    test('each mutation increments generation', () {
      final store = container.read(presenceStoreProvider.notifier);

      store.setOnline('user-1');
      expect(container.read(presenceStoreProvider).generation, 1);

      store.setIdle('user-1');
      expect(container.read(presenceStoreProvider).generation, 2);

      store.setOffline('user-1');
      expect(container.read(presenceStoreProvider).generation, 3);

      store.setPresence('user-2', 'online');
      expect(container.read(presenceStoreProvider).generation, 4);

      store.setOnlineList(['user-3', 'user-4']);
      expect(container.read(presenceStoreProvider).generation, 5);

      store.clearAll();
      expect(container.read(presenceStoreProvider).generation, 6);
    });

    test('idempotent mutations do NOT increment generation', () {
      final store = container.read(presenceStoreProvider.notifier);

      store.setOnline('user-1');
      final gen1 = container.read(presenceStoreProvider).generation;

      // Setting same user online again — no-op.
      store.setOnline('user-1');
      expect(container.read(presenceStoreProvider).generation, gen1);

      store.setIdle('user-1');
      final gen2 = container.read(presenceStoreProvider).generation;

      // Setting same user idle again — no-op.
      store.setIdle('user-1');
      expect(container.read(presenceStoreProvider).generation, gen2);

      // Removing an already-offline user — no-op.
      store.setOffline('user-nonexistent');
      expect(container.read(presenceStoreProvider).generation, gen2);
    });

    test('equality is content-based (mapEquals) not generation-based', () {
      final a = PresenceState(
        statuses: {'u1': UserPresenceStatus.online},
        generation: 5,
      );
      final b = PresenceState(
        statuses: {'u1': UserPresenceStatus.online},
        generation: 99,
      );
      // Same content → equal (regardless of generation).
      expect(a, equals(b));
    });

    test('equality: different content means not equal', () {
      final a = PresenceState(
        statuses: {'u1': UserPresenceStatus.online},
        generation: 5,
      );
      final b = PresenceState(
        statuses: {'u1': UserPresenceStatus.idle},
        generation: 5,
      );
      expect(a, isNot(equals(b)));
    });

    test('updateShouldNotify uses generation for O(1) notification', () {
      final store = container.read(presenceStoreProvider.notifier);
      final states = <PresenceState>[];
      container.listen(presenceStoreProvider, (_, next) {
        states.add(next);
      });

      store.setOnline('user-1');
      store.setIdle('user-1');
      store.setOffline('user-1');

      // Each mutation has a new generation → each notifies.
      expect(states.length, 3);
      expect(states[0].statusOf('user-1'), UserPresenceStatus.online);
      expect(states[1].statusOf('user-1'), UserPresenceStatus.idle);
      expect(states[2].statusOf('user-1'), UserPresenceStatus.offline);
    });
  });

  group('#689 — Dispose flash fix', () {
    test('disposing binding does NOT produce clearAll notification', () async {
      final container = ProviderContainer();
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      final store = container.read(presenceStoreProvider.notifier);
      final ingress = RealtimeReductionIngress();
      final binding = PresenceRealtimeBinding(
        store: store,
        ingress: ingress,
        currentUserId: 'me',
      );

      binding.bind();

      // Simulate user coming online.
      ingress.accept(RealtimeEventEnvelope(
        eventType: kUserPresenceEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-1',
          'status': 'online',
        },
      ));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(presenceStoreProvider).isOnline('user-1'),
        isTrue,
      );

      // Track state changes during dispose.
      final statesDuringDispose = <PresenceState>[];
      container.listen(presenceStoreProvider, (_, next) {
        statesDuringDispose.add(next);
      });

      // Dispose binding — should NOT clear presence.
      binding.dispose();
      await Future<void>.delayed(Duration.zero);

      // No transient empty-state notification should have been emitted.
      expect(
        statesDuringDispose,
        isEmpty,
        reason:
            'Disposing binding should not emit clearAll / empty-state notification',
      );

      // Presence data should still be intact (store still alive via sub).
      expect(
        container.read(presenceStoreProvider).isOnline('user-1'),
        isTrue,
        reason: 'Presence data should remain after binding dispose',
      );

      sub.close();
      container.dispose();
    });
  });
}
