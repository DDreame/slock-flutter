import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/realtime/realtime_event_envelope.dart';
import 'package:slock_app/core/realtime/realtime_reduction_ingress.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';
import 'package:slock_app/features/presence/data/presence_realtime_binding.dart';

void main() {
  late ProviderContainer container;
  late PresenceStore store;
  late RealtimeReductionIngress ingress;
  late PresenceRealtimeBinding binding;
  ProviderSubscription<PresenceState>? sub;

  setUp(() {
    container = ProviderContainer();
    sub = container.listen(presenceStoreProvider, (_, __) {});
    store = container.read(presenceStoreProvider.notifier);
    ingress = RealtimeReductionIngress();
    binding = PresenceRealtimeBinding(
      store: store,
      ingress: ingress,
      currentUserId: 'current-user',
    );
  });

  tearDown(() {
    binding.dispose();
    sub?.close();
    container.dispose();
  });

  group('PresenceRealtimeBinding — receive', () {
    test('user:presence with online status marks user online', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kUserPresenceEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-2',
          'status': 'online',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(presenceStoreProvider);
      expect(state.statusOf('user-2'), UserPresenceStatus.online);
    });

    test('user:presence with idle status marks user idle', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kUserPresenceEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-2',
          'status': 'idle',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(presenceStoreProvider);
      expect(state.statusOf('user-2'), UserPresenceStatus.idle);
    });

    test('user:presence with offline status marks user offline', () async {
      binding.bind();

      // First set online.
      ingress.accept(RealtimeEventEnvelope(
        eventType: kUserPresenceEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-2',
          'status': 'online',
        },
      ));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(presenceStoreProvider).isOnline('user-2'), isTrue);

      // Then set offline.
      ingress.accept(RealtimeEventEnvelope(
        eventType: kUserPresenceEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-2',
          'status': 'offline',
        },
      ));
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(presenceStoreProvider).statusOf('user-2'),
        UserPresenceStatus.offline,
      );
    });

    test('ignores presence events from current user', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kUserPresenceEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'current-user',
          'status': 'online',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(presenceStoreProvider);
      expect(state.statuses, isEmpty);
    });

    test('ignores non-presence events', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-2',
          'status': 'online',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(presenceStoreProvider);
      expect(state.statuses, isEmpty);
    });

    test('ignores event with missing userId', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kUserPresenceEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'status': 'online',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(presenceStoreProvider);
      expect(state.statuses, isEmpty);
    });

    test('null presence label maps to offline', () async {
      binding.bind();

      // First set online.
      ingress.accept(RealtimeEventEnvelope(
        eventType: kUserPresenceEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-2',
          'status': 'online',
        },
      ));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(presenceStoreProvider).isOnline('user-2'), isTrue);

      // Send event with no presence field.
      ingress.accept(RealtimeEventEnvelope(
        eventType: kUserPresenceEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-2',
        },
      ));
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(presenceStoreProvider).statusOf('user-2'),
        UserPresenceStatus.offline,
      );
    });
  });

  group('PresenceRealtimeBinding — dispose', () {
    test('dispose stops listening but does NOT clear state (no flash)',
        () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kUserPresenceEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-2',
          'status': 'online',
        },
      ));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(presenceStoreProvider).isOnline('user-2'), isTrue);

      binding.dispose();

      // State is preserved — autoDispose teardown handles reset.
      expect(
        container.read(presenceStoreProvider).isOnline('user-2'),
        isTrue,
        reason: 'Dispose should not clear state (prevents flash)',
      );

      // Verify listening stopped — new events should not update store.
      ingress.accept(RealtimeEventEnvelope(
        eventType: kUserPresenceEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-3',
          'status': 'online',
        },
      ));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(presenceStoreProvider).isOnline('user-3'),
        isFalse,
        reason: 'After dispose, new events should not be processed',
      );
    });
  });
}
