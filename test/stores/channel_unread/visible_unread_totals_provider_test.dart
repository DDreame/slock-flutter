import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';
import 'package:slock_app/stores/channel_unread/visible_unread_totals_provider.dart';

import '../../core/local_data/fake_conversation_local_store.dart';
import '../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

void main() {
  const serverId = ServerScopeId('server-1');
  const channelScopeId = ChannelScopeId(
    serverId: serverId,
    value: 'general',
  );
  const channel2ScopeId = ChannelScopeId(
    serverId: serverId,
    value: 'random',
  );
  const dmScopeId = DirectMessageScopeId(
    serverId: serverId,
    value: 'dm-alice',
  );
  const dm2ScopeId = DirectMessageScopeId(
    serverId: serverId,
    value: 'dm-bob',
  );

  ProviderContainer createContainer({
    List<HomeChannelSummary> channels = const [
      HomeChannelSummary(scopeId: channelScopeId, name: 'general'),
      HomeChannelSummary(scopeId: channel2ScopeId, name: 'random'),
    ],
    List<HomeDirectMessageSummary> directMessages = const [
      HomeDirectMessageSummary(scopeId: dmScopeId, title: 'Alice'),
      HomeDirectMessageSummary(scopeId: dm2ScopeId, title: 'Bob'),
    ],
    SidebarOrder sidebarOrder = const SidebarOrder(),
  }) {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
        activeServerScopeIdProvider.overrideWithValue(serverId),
        conversationLocalStoreProvider.overrideWithValue(
          FakeConversationLocalStore(),
        ),
        sidebarOrderRepositoryProvider
            .overrideWithValue(_FakeSidebarOrderRepository(sidebarOrder)),
        homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
          (scopeId) async => HomeWorkspaceSnapshot(
            serverId: scopeId,
            channels: channels,
            directMessages: directMessages,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('visibleChannelUnreadTotalProvider', () {
    test('sums only visible channel unreads', () async {
      final container = createContainer();
      await container.read(homeListStoreProvider.notifier).load();

      // Hydrate with counts for visible channels + a thread/unknown ID.
      container
          .read(channelUnreadStoreProvider.notifier)
          .hydrateChannelUnreads({
        channelScopeId: 3,
        channel2ScopeId: 2,
        // This is a thread channel or unknown — not in home list.
        const ChannelScopeId(serverId: serverId, value: 'thread-ch-xyz'): 5,
      });

      final total = container.read(visibleChannelUnreadTotalProvider);
      // Only general(3) + random(2) = 5, not thread-ch-xyz(5).
      expect(total, 5);
    });

    test('thread channel unread does NOT inflate channel tab badge', () async {
      final container = createContainer();
      await container.read(homeListStoreProvider.notifier).load();

      container
          .read(channelUnreadStoreProvider.notifier)
          .hydrateChannelUnreads({
        channelScopeId: 1,
        // Thread channel ID in channel bucket (hydration bug scenario).
        const ChannelScopeId(serverId: serverId, value: 'thread-ch-abc'): 10,
      });

      final total = container.read(visibleChannelUnreadTotalProvider);
      expect(total, 1);
    });

    test('unknown channel unread does NOT inflate channel tab badge', () async {
      final container = createContainer();
      await container.read(homeListStoreProvider.notifier).load();

      container
          .read(channelUnreadStoreProvider.notifier)
          .hydrateChannelUnreads({
        channelScopeId: 2,
        // Archived/unknown channel — not in home list.
        const ChannelScopeId(serverId: serverId, value: 'archived-ch'): 8,
      });

      final total = container.read(visibleChannelUnreadTotalProvider);
      expect(total, 2);
    });

    test('visible channel unread renders on row and contributes to badge',
        () async {
      final container = createContainer();
      await container.read(homeListStoreProvider.notifier).load();

      container
          .read(channelUnreadStoreProvider.notifier)
          .hydrateChannelUnreads({
        channelScopeId: 4,
        channel2ScopeId: 3,
      });

      final total = container.read(visibleChannelUnreadTotalProvider);
      expect(total, 7);

      // Individual channel counts are still available for row badges.
      final state = container.read(channelUnreadStoreProvider);
      expect(state.channelUnreadCount(channelScopeId), 4);
      expect(state.channelUnreadCount(channel2ScopeId), 3);
    });
  });

  group('visibleDmUnreadTotalProvider', () {
    test('sums only visible DM unreads', () async {
      final container = createContainer();
      await container.read(homeListStoreProvider.notifier).load();

      container.read(channelUnreadStoreProvider.notifier).hydrateDmUnreads({
        dmScopeId: 2,
        dm2ScopeId: 1,
        // Unknown DM not in home list.
        const DirectMessageScopeId(serverId: serverId, value: 'dm-ghost'): 5,
      });

      final total = container.read(visibleDmUnreadTotalProvider);
      // Only alice(2) + bob(1) = 3, not ghost(5).
      expect(total, 3);
    });

    test('visible DM unread renders on row and contributes to badge', () async {
      final container = createContainer();
      await container.read(homeListStoreProvider.notifier).load();

      container.read(channelUnreadStoreProvider.notifier).hydrateDmUnreads({
        dmScopeId: 5,
        dm2ScopeId: 3,
      });

      final total = container.read(visibleDmUnreadTotalProvider);
      expect(total, 8);

      final state = container.read(channelUnreadStoreProvider);
      expect(state.dmUnreadCount(dmScopeId), 5);
      expect(state.dmUnreadCount(dm2ScopeId), 3);
    });

    test('hidden DM unread does NOT contribute to DM tab badge', () async {
      final container = createContainer(
        sidebarOrder: const SidebarOrder(hiddenDmIds: ['dm-bob']),
      );
      await container.read(homeListStoreProvider.notifier).load();

      container.read(channelUnreadStoreProvider.notifier).hydrateDmUnreads({
        dmScopeId: 2,
        dm2ScopeId: 4, // Bob is hidden — should NOT count.
      });

      final total = container.read(visibleDmUnreadTotalProvider);
      expect(total, 2);
    });
  });
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository(this._order);

  final SidebarOrder _order;

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    return _order;
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}
