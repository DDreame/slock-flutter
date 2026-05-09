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
    test('initial state has no online users', () {
      final state = container.read(presenceStoreProvider);
      expect(state.onlineUserIds, isEmpty);
    });

    test('setOnline adds a user to online set', () {
      container.read(presenceStoreProvider.notifier).setOnline('user-1');

      final state = container.read(presenceStoreProvider);
      expect(state.onlineUserIds, contains('user-1'));
    });

    test('setOnline is idempotent', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      notifier.setOnline('user-1');
      notifier.setOnline('user-1');

      final state = container.read(presenceStoreProvider);
      expect(state.onlineUserIds, hasLength(1));
    });

    test('setOffline removes a user from online set', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      notifier.setOnline('user-1');
      notifier.setOffline('user-1');

      final state = container.read(presenceStoreProvider);
      expect(state.onlineUserIds, isEmpty);
    });

    test('setOffline on unknown user is a no-op', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      notifier.setOnline('user-1');
      notifier.setOffline('user-unknown');

      final state = container.read(presenceStoreProvider);
      expect(state.onlineUserIds, hasLength(1));
    });

    test('setOnlineList replaces online set with given user IDs', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      notifier.setOnline('user-old');
      notifier.setOnlineList(['user-1', 'user-2', 'user-3']);

      final state = container.read(presenceStoreProvider);
      expect(
        state.onlineUserIds,
        unorderedEquals(['user-1', 'user-2', 'user-3']),
      );
      expect(state.onlineUserIds, isNot(contains('user-old')));
    });

    test('clearAll removes all users', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      notifier.setOnline('user-1');
      notifier.setOnline('user-2');
      notifier.clearAll();

      final state = container.read(presenceStoreProvider);
      expect(state.onlineUserIds, isEmpty);
    });
  });

  group('PresenceState.isOnline', () {
    test('returns true for an online user', () {
      container.read(presenceStoreProvider.notifier).setOnline('user-1');

      final state = container.read(presenceStoreProvider);
      expect(state.isOnline('user-1'), isTrue);
    });

    test('returns false for an offline user', () {
      final state = container.read(presenceStoreProvider);
      expect(state.isOnline('user-unknown'), isFalse);
    });

    test('returns false after user goes offline', () {
      final notifier = container.read(presenceStoreProvider.notifier);
      notifier.setOnline('user-1');
      notifier.setOffline('user-1');

      final state = container.read(presenceStoreProvider);
      expect(state.isOnline('user-1'), isFalse);
    });
  });

  group('PresenceState.statusOf', () {
    test('returns online for online user', () {
      container.read(presenceStoreProvider.notifier).setOnline('user-1');

      final state = container.read(presenceStoreProvider);
      expect(state.statusOf('user-1'), UserPresenceStatus.online);
    });

    test('returns offline for unknown user', () {
      final state = container.read(presenceStoreProvider);
      expect(state.statusOf('user-1'), UserPresenceStatus.offline);
    });
  });
}
