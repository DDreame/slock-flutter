// =============================================================================
// #755 — Memory + Concurrency Safety
//
// A. P2: HomeListStore._allAgents race — concurrent supplemental callbacks
//    from overlapping _loadAndMergeSupplemental calls can overwrite with stale
//    data. Fix: generation counter discards callbacks from superseded loads.
// B. P2: InboxStore._knownItemsByChannelId unbounded growth — items accumulate
//    without limit. Fix: cap at 500 entries with oldest-first eviction.
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/conversation_unread_repository.dart';
import 'package:slock_app/features/inbox/data/conversation_unread_repository_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';

import '../support/support.dart';

void main() {
  // ---------------------------------------------------------------------------
  // #755A — HomeListStore supplemental generation guard
  // ---------------------------------------------------------------------------
  group('#755A — HomeListStore supplemental race prevention', () {
    test(
      'concurrent supplemental loads — only latest generation writes state',
      () async {
        // Two agent loads: first one is slow, second is fast.
        // Without the generation guard, the slow first load would overwrite
        // the fast second load's results.
        final firstGate = Completer<List<AgentItem>>();
        final secondGate = Completer<List<AgentItem>>();
        var loadCount = 0;

        final agentsRepo = _SequentialAgentsRepository(
          gates: [firstGate, secondGate],
          onLoad: () => loadCount++,
        );

        final fixture = RuntimeAppFixture(
          extraOverrides: [
            agentsRepositoryProvider.overrideWithValue(agentsRepo),
          ],
        );
        fixture.seedHome(
          channels: [
            const HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'general',
              ),
              name: 'general',
            ),
          ],
        );

        await fixture.boot();
        addTearDown(fixture.dispose);

        // boot() triggers load → starts first _loadAndMergeSupplemental.
        // The first gate is still pending.
        expect(loadCount, 1, reason: 'First supplemental load started');

        // Trigger refresh → starts second _loadAndMergeSupplemental.
        fixture.container.read(homeListStoreProvider.notifier).refresh(
              reason: 'test',
            );
        // Allow the refresh to start the second supplemental load.
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(loadCount, 2, reason: 'Second supplemental load started');

        // Complete second load FIRST with "fresh" agents.
        secondGate.complete([
          const AgentItem(
            id: 'agent-fresh',
            name: 'Fresh Agent',
            model: 'claude',
            runtime: 'codex',
            status: 'active',
            activity: 'idle',
          ),
        ]);
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        // Complete first (stale) load with different agents.
        firstGate.complete([
          const AgentItem(
            id: 'agent-stale',
            name: 'Stale Agent',
            model: 'claude',
            runtime: 'codex',
            status: 'active',
            activity: 'idle',
          ),
          const AgentItem(
            id: 'agent-stale-2',
            name: 'Stale Agent 2',
            model: 'claude',
            runtime: 'codex',
            status: 'active',
            activity: 'idle',
          ),
        ]);
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        // The state should have the SECOND load's data, not the first.
        final state = fixture.container.read(homeListStoreProvider);
        expect(state.agents, hasLength(1),
            reason: '#755: Stale supplemental callback must be discarded');
        expect(state.agents.first.id, 'agent-fresh');
      },
    );

    test('single supplemental load works normally', () async {
      final agentsCompleter = Completer<List<AgentItem>>();
      final agentsRepo = _SequentialAgentsRepository(
        gates: [agentsCompleter],
        onLoad: () {},
      );

      final fixture = RuntimeAppFixture(
        extraOverrides: [
          agentsRepositoryProvider.overrideWithValue(agentsRepo),
        ],
      );
      fixture.seedHome(
        channels: [
          const HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'general',
            ),
            name: 'general',
          ),
        ],
      );

      await fixture.boot();
      addTearDown(fixture.dispose);

      // boot() started the agents load — complete it now.
      agentsCompleter.complete([
        const AgentItem(
          id: 'agent-1',
          name: 'Alpha',
          model: 'claude',
          runtime: 'codex',
          status: 'active',
          activity: 'idle',
        ),
      ]);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = fixture.container.read(homeListStoreProvider);
      expect(state.agents, hasLength(1));
      expect(state.agents.first.label, 'Alpha');
    });
  });

  // ---------------------------------------------------------------------------
  // #755B — InboxStore bounded _knownItemsByChannelId
  // ---------------------------------------------------------------------------
  group('#755B — InboxStore known items eviction', () {
    test(
      '_knownItemsByChannelId evicts oldest entries at capacity',
      () async {
        // Create a repo that returns many items to fill the cache past capacity.
        final items = List.generate(
          InboxStore.maxKnownItems + 50,
          (i) => InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-$i',
            channelName: 'Channel $i',
            unreadCount: 1,
          ),
        );

        final repo = _PagedInboxRepository(allItems: items);
        final container = ProviderContainer(
          overrides: [
            inboxRepositoryProvider.overrideWithValue(repo),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('server-1')),
            conversationUnreadRepositoryProvider
                .overrideWithValue(const _FakeConversationUnreadRepository()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(inboxStoreProvider.notifier);

        // Load first page (fills some of the cache).
        await notifier.load();
        // Load remaining via loadMore until all items are loaded.
        while (container.read(inboxStoreProvider).hasMore) {
          await notifier.loadMore();
        }

        // All items loaded — verify state.
        final state = container.read(inboxStoreProvider);
        expect(state.items.length, InboxStore.maxKnownItems + 50);

        // Now test that marking an early channel as unread (which got evicted
        // from _knownItemsByChannelId) falls back to a placeholder since the
        // known cache was capped.
        //
        // First, remove ch-0 from visible items to simulate it going off-screen.
        // We do this by reloading with only recent items.
        repo.allItems = items.sublist(50); // Drop first 50 items from load.
        await notifier.load();

        // Now mark ch-0 (evicted from known cache) as unread.
        await notifier.markAsUnread(channelId: 'ch-0');

        // The item should be present but with fallback data (no channelName
        // from cache since it was evicted).
        final updatedState = container.read(inboxStoreProvider);
        final ch0 =
            updatedState.items.where((i) => i.channelId == 'ch-0').firstOrNull;
        expect(ch0, isNotNull,
            reason: 'Item must still be insertable even if evicted from cache');
        // Evicted items get a minimal placeholder (no cached channelName).
        expect(ch0!.unreadCount, 1);
      },
    );

    test('active inbox items are not lost during eviction', () async {
      // Load exactly maxKnownItems items, then verify they're all accessible.
      final items = List.generate(
        InboxStore.maxKnownItems,
        (i) => InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-$i',
          channelName: 'Channel $i',
          unreadCount: 1,
        ),
      );

      final repo = _PagedInboxRepository(allItems: items);
      final container = ProviderContainer(
        overrides: [
          inboxRepositoryProvider.overrideWithValue(repo),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      while (container.read(inboxStoreProvider).hasMore) {
        await container.read(inboxStoreProvider.notifier).loadMore();
      }

      final state = container.read(inboxStoreProvider);
      expect(state.items.length, InboxStore.maxKnownItems,
          reason: 'All items at capacity should be loaded without loss');
    });
  });
}

// =============================================================================
// Test Doubles
// =============================================================================

class _SequentialAgentsRepository implements AgentsRepository {
  _SequentialAgentsRepository({
    required this.gates,
    required this.onLoad,
  });

  final List<Completer<List<AgentItem>>> gates;
  final void Function() onLoad;
  int _callCount = 0;

  @override
  Future<List<AgentItem>> listAgents() async {
    final index = _callCount++;
    onLoad();
    if (index < gates.length) {
      return gates[index].future;
    }
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Repository that pages through [allItems] in chunks.
class _PagedInboxRepository implements InboxRepository {
  _PagedInboxRepository({required this.allItems});

  List<InboxItem> allItems;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    final end = (offset + limit).clamp(0, allItems.length);
    final page = allItems.sublist(offset.clamp(0, allItems.length), end);
    return InboxResponse(
      items: page,
      totalCount: allItems.length,
      totalUnreadCount: allItems.fold(0, (sum, i) => sum + i.unreadCount),
      hasMore: end < allItems.length,
    );
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

class _FakeConversationUnreadRepository
    implements ConversationUnreadRepository {
  const _FakeConversationUnreadRepository();

  @override
  Future<void> markAsUnread(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}
}
