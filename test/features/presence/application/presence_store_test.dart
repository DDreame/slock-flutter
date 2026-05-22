import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';

void main() {
  late ProviderContainer container;
  ProviderSubscription<PresenceState>? sub;

  setUp(() {
    container = ProviderContainer();
    sub = container.listen(presenceStoreProvider, (_, __) {});
  });

  tearDown(() {
    sub?.close();
    container.dispose();
  });

  group('PresenceStore', () {
    test('initial state has no users', () {
      final state = container.read(presenceStoreProvider);
      expect(state.onlineUserIds, isEmpty);
      expect(state.statuses, isEmpty);
    });

    test('setOnline adds a user as online', () {
      container.read(presenceStoreProvider.notifier).setOnline('user-1');

      final state = container.read(presenceStoreProvider);
      expect(state.onlineUserIds, contains('user-1'));
      expect(state.statusOf('user-1'), UserPresenceStatus.online);
    });

    test('setOnline is idempotent', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      notifier.setOnline('user-1');
      notifier.setOnline('user-1');

      final state = container.read(presenceStoreProvider);
      expect(state.onlineUserIds, hasLength(1));
    });

    test('setIdle marks a user as idle', () {
      container.read(presenceStoreProvider.notifier).setIdle('user-1');

      final state = container.read(presenceStoreProvider);
      expect(state.statusOf('user-1'), UserPresenceStatus.idle);
      expect(state.isOnline('user-1'), isFalse);
    });

    test('setOffline removes a user from statuses', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      notifier.setOnline('user-1');
      notifier.setOffline('user-1');

      final state = container.read(presenceStoreProvider);
      expect(state.onlineUserIds, isEmpty);
      expect(state.statusOf('user-1'), UserPresenceStatus.offline);
    });

    test('setOffline on unknown user is a no-op', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      notifier.setOnline('user-1');
      notifier.setOffline('user-unknown');

      final state = container.read(presenceStoreProvider);
      expect(state.onlineUserIds, hasLength(1));
    });

    test('setPresence parses label strings correctly', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      notifier.setPresence('user-1', 'online');
      notifier.setPresence('user-2', 'idle');
      notifier.setPresence('user-3', 'offline');

      final state = container.read(presenceStoreProvider);
      expect(state.statusOf('user-1'), UserPresenceStatus.online);
      expect(state.statusOf('user-2'), UserPresenceStatus.idle);
      expect(state.statusOf('user-3'), UserPresenceStatus.offline);
    });

    test('setPresence with null label sets offline', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      notifier.setOnline('user-1');
      notifier.setPresence('user-1', null);

      final state = container.read(presenceStoreProvider);
      expect(state.statusOf('user-1'), UserPresenceStatus.offline);
    });

    test('setOnlineList replaces all statuses', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      notifier.setOnline('user-old');
      notifier.setOnlineList(['user-1', 'user-2', 'user-3']);

      final state = container.read(presenceStoreProvider);
      expect(
        state.onlineUserIds,
        unorderedEquals(['user-1', 'user-2', 'user-3']),
      );
      expect(state.isOnline('user-old'), isFalse);
    });

    test('caps statuses at 500 and evicts offline entries first', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      for (var i = 0; i < 500; i++) {
        notifier.setOnline('online-$i');
      }
      for (var i = 0; i < 50; i++) {
        notifier.setIdle('offline-candidate-$i');
        notifier.setPresence('offline-candidate-$i', 'offline');
      }
      notifier.setOnline('new-online');

      final state = container.read(presenceStoreProvider);
      expect(state.statuses.length, PresenceStore.maxPresenceStatuses);
      expect(state.statusOf('new-online'), UserPresenceStatus.online);
      expect(
        state.statuses.keys.where((id) => id.startsWith('offline-candidate')),
        isEmpty,
        reason: '#762: offline entries should be evicted before active ones',
      );
    });

    test('clearAll removes all users', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      notifier.setOnline('user-1');
      notifier.setIdle('user-2');
      notifier.clearAll();

      final state = container.read(presenceStoreProvider);
      expect(state.statuses, isEmpty);
    });
  });

  group('PresenceState.hashCode', () {
    test('distinguishes swapped field values', () {
      const stateA = PresenceState(
        statuses: {
          'user-a': UserPresenceStatus.online,
          'user-b': UserPresenceStatus.idle,
        },
      );
      const stateB = PresenceState(
        statuses: {
          'user-a': UserPresenceStatus.idle,
          'user-b': UserPresenceStatus.online,
        },
      );

      expect(stateA, isNot(equals(stateB)));
      expect(stateA.hashCode, isNot(equals(stateB.hashCode)));
    });

    test('is stable for equal maps with different insertion order', () {
      const stateA = PresenceState(
        statuses: {
          'user-a': UserPresenceStatus.online,
          'user-b': UserPresenceStatus.idle,
        },
      );
      const stateB = PresenceState(
        statuses: {
          'user-b': UserPresenceStatus.idle,
          'user-a': UserPresenceStatus.online,
        },
      );

      expect(stateA, stateB);
      expect(stateA.hashCode, stateB.hashCode);
    });
  });

  group('PresenceState.statusOf', () {
    test('returns online for online user', () {
      container.read(presenceStoreProvider.notifier).setOnline('user-1');
      expect(
        container.read(presenceStoreProvider).statusOf('user-1'),
        UserPresenceStatus.online,
      );
    });

    test('returns idle for idle user', () {
      container.read(presenceStoreProvider.notifier).setIdle('user-1');
      expect(
        container.read(presenceStoreProvider).statusOf('user-1'),
        UserPresenceStatus.idle,
      );
    });

    test('returns offline for unknown user', () {
      expect(
        container.read(presenceStoreProvider).statusOf('user-1'),
        UserPresenceStatus.offline,
      );
    });
  });
}
