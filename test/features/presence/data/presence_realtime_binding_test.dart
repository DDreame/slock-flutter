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
    test('presence:online event marks user as online', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kPresenceOnlineEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-2',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(presenceStoreProvider);
      expect(state.isOnline('user-2'), isTrue);
    });

    test('presence:offline event marks user as offline', () async {
      binding.bind();

      // First set online.
      ingress.accept(RealtimeEventEnvelope(
        eventType: kPresenceOnlineEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-2',
        },
      ));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(presenceStoreProvider).isOnline('user-2'), isTrue);

      // Then set offline.
      ingress.accept(RealtimeEventEnvelope(
        eventType: kPresenceOfflineEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-2',
        },
      ));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(presenceStoreProvider);
      expect(state.isOnline('user-2'), isFalse);
    });

    test('presence:list event sets initial online list', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kPresenceListEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userIds': ['user-1', 'user-2', 'user-3'],
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(presenceStoreProvider);
      expect(state.isOnline('user-1'), isTrue);
      expect(state.isOnline('user-2'), isTrue);
      expect(state.isOnline('user-3'), isTrue);
      expect(state.isOnline('user-unknown'), isFalse);
    });

    test('ignores presence events from current user', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kPresenceOnlineEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'current-user',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(presenceStoreProvider);
      expect(state.isOnline('current-user'), isFalse);
    });

    test('ignores non-presence events', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-2',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(presenceStoreProvider);
      expect(state.onlineUserIds, isEmpty);
    });

    test('ignores event with missing userId', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kPresenceOnlineEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'other': 'data',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(presenceStoreProvider);
      expect(state.onlineUserIds, isEmpty);
    });
  });

  group('PresenceRealtimeBinding — dispose', () {
    test('dispose clears state and stops listening', () async {
      binding.bind();

      ingress.accept(RealtimeEventEnvelope(
        eventType: kPresenceOnlineEvent,
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: const {
          'userId': 'user-2',
        },
      ));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(presenceStoreProvider).isOnline('user-2'), isTrue);

      binding.dispose();

      expect(
        container.read(presenceStoreProvider).onlineUserIds,
        isEmpty,
      );
    });
  });
}
