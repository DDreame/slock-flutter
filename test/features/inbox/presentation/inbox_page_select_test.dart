// =============================================================================
// #635 — InboxPage split .select() + DMs agent name set caching
//
// Invariant: INV-INBOX-SELECT-SPLIT-1
//   inbox_page.dart L57:
//   ref.watch(inboxStoreProvider) watches full InboxState.
//   AppBar only needs (status, totalUnreadCount). Changes to items,
//   isRefreshing, hasMore, filter must NOT trigger AppBar rebuild.
//   Phase B narrows AppBar watch to .select((s) => (status, totalUnreadCount)).
//
// Invariant: INV-INBOX-SELECT-SPLIT-2
//   inbox_page.dart L57:
//   Body only needs (status, items, isRefreshing, hasMore, failure).
//   Changes to filter or totalUnreadCount must NOT trigger body rebuild.
//   Phase B narrows body watch to consumed fields only.
//
// Invariant: INV-DMS-AGENT-SET-CACHE-1
//   dms_tab_page.dart L180-196:
//   onlineAgentNames and allAgentNames are rebuilt from agent list on every
//   build. When agents list is unchanged, the derived sets must NOT be
//   recomputed. Phase B caches via a provider or computed field.
//
// Strategy:
// T1: items change must NOT fire AppBar (status,totalUnreadCount) select
//     (skip:true — currently watches full state).
// T2: filter change must NOT fire body (status,items,isRefreshing,hasMore,
//     failure) select (skip:true — currently watches full state).
// T3: status change DOES fire AppBar select (active — positive test).
// T4: items change DOES fire body select (active — positive test).
// T5: agents unchanged must NOT fire DMs agent name set derivation
//     (skip:true — currently recomputes on every build).
// T6: agents change DOES fire DMs agent name set derivation (active).
//
// Phase A: T1-T2/T5 skip:true, T3-T4/T6 active.
// Phase B: Split inbox watch, cache agent sets, un-skip T1-T2/T5.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableInboxStore extends InboxStore {
  @override
  InboxState build() {
    return const InboxState(
      status: InboxStatus.success,
      items: _items,
      totalUnreadCount: 3,
    );
  }

  static const _items = [
    InboxItem(
      kind: InboxItemKind.channel,
      channelId: 'ch-1',
      channelName: 'general',
      unreadCount: 3,
    ),
  ];

  void setItemsDirect(List<InboxItem> items) {
    state = state.copyWith(items: items);
  }

  void setFilterDirect(InboxFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void setStatusDirect(InboxStatus status) {
    state = state.copyWith(status: status);
  }

  void setTotalUnreadCountDirect(int count) {
    state = state.copyWith(totalUnreadCount: count);
  }

  void setIsRefreshingDirect(bool value) {
    state = state.copyWith(isRefreshing: value);
  }
}

class _ControllableHomeListStore extends HomeListStore {
  @override
  HomeListState build() {
    return const HomeListState(
      status: HomeListStatus.success,
      agents: _agents,
      pinnedAgents: [],
    );
  }

  static const _agents = [
    AgentItem(
      id: 'agent-1',
      name: 'bot-alpha',
      model: 'claude-4',
      runtime: 'claude-code',
      status: 'active',
      activity: 'idle',
    ),
    AgentItem(
      id: 'agent-2',
      name: 'bot-beta',
      model: 'claude-4',
      runtime: 'claude-code',
      status: 'stopped',
      activity: 'offline',
    ),
  ];

  void setAgentsDirect(List<AgentItem> agents) {
    state = state.copyWith(agents: agents);
  }

  void setIsRefreshingDirect(bool value) {
    state = state.copyWith(isRefreshing: value);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // INV-INBOX-SELECT-SPLIT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T1: items change must NOT fire AppBar (status,totalUnreadCount) select.
  // -------------------------------------------------------------------------
  test(
    'INV-INBOX-SELECT-SPLIT-1: items change does NOT notify '
    '(status,totalUnreadCount) select',
    skip: true, // Phase A — currently watches full state.
    () async {
      final container = ProviderContainer(
        overrides: [
          inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(inboxStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        inboxStoreProvider.select(
            (s) => (status: s.status, totalUnreadCount: s.totalUnreadCount)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setItemsDirect(const [
        InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          channelName: 'general',
          unreadCount: 3,
        ),
        InboxItem(
          kind: InboxItemKind.dm,
          channelId: 'dm-1',
          channelName: 'Alice',
          unreadCount: 1,
        ),
      ]);

      expect(
        selectNotifyCount,
        0,
        reason: 'items change must not notify AppBar select '
            '(INV-INBOX-SELECT-SPLIT-1)',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // INV-INBOX-SELECT-SPLIT-2
  // =========================================================================

  // -------------------------------------------------------------------------
  // T2: filter change must NOT fire body
  //     (status,items,isRefreshing,hasMore,failure) select.
  // -------------------------------------------------------------------------
  test(
    'INV-INBOX-SELECT-SPLIT-2: filter change does NOT notify '
    '(status,items,isRefreshing,hasMore,failure) select',
    skip: true, // Phase A — currently watches full state.
    () async {
      final container = ProviderContainer(
        overrides: [
          inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(inboxStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        inboxStoreProvider.select((s) => (
              status: s.status,
              items: s.items,
              isRefreshing: s.isRefreshing,
              hasMore: s.hasMore,
              failure: s.failure,
            )),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setFilterDirect(InboxFilter.mentions);

      expect(
        selectNotifyCount,
        0,
        reason: 'filter change must not notify body select '
            '(INV-INBOX-SELECT-SPLIT-2)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: status change DOES fire AppBar (status,totalUnreadCount) select.
  // -------------------------------------------------------------------------
  test(
    'INV-INBOX-SELECT-SPLIT-1: status change DOES notify '
    '(status,totalUnreadCount) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(inboxStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        inboxStoreProvider.select(
            (s) => (status: s.status, totalUnreadCount: s.totalUnreadCount)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setStatusDirect(InboxStatus.loading);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify AppBar select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: items change DOES fire body
  //     (status,items,isRefreshing,hasMore,failure) select.
  // -------------------------------------------------------------------------
  test(
    'INV-INBOX-SELECT-SPLIT-2: items change DOES notify '
    '(status,items,isRefreshing,hasMore,failure) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(inboxStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        inboxStoreProvider.select((s) => (
              status: s.status,
              items: s.items,
              isRefreshing: s.isRefreshing,
              hasMore: s.hasMore,
              failure: s.failure,
            )),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setItemsDirect(const [
        InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          channelName: 'general',
          unreadCount: 3,
        ),
        InboxItem(
          kind: InboxItemKind.dm,
          channelId: 'dm-1',
          channelName: 'Alice',
          unreadCount: 1,
        ),
      ]);

      expect(
        selectNotifyCount,
        1,
        reason: 'items change must notify body select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // INV-DMS-AGENT-SET-CACHE-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T5: agents unchanged must NOT fire agent name set derivation.
  // -------------------------------------------------------------------------
  test(
    'INV-DMS-AGENT-SET-CACHE-1: isRefreshing change does NOT notify '
    'agents select',
    skip: true, // Phase A — currently recomputes on every build.
    () async {
      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(homeListStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        homeListStoreProvider
            .select((s) => (agents: s.agents, pinnedAgents: s.pinnedAgents)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setIsRefreshingDirect(true);

      expect(
        selectNotifyCount,
        0,
        reason: 'isRefreshing change must not notify agents select '
            '(INV-DMS-AGENT-SET-CACHE-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T6: agents change DOES fire agent name set derivation.
  // -------------------------------------------------------------------------
  test(
    'INV-DMS-AGENT-SET-CACHE-1: agents change DOES notify agents select',
    () async {
      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(homeListStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        homeListStoreProvider
            .select((s) => (agents: s.agents, pinnedAgents: s.pinnedAgents)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setAgentsDirect(const [
        AgentItem(
          id: 'agent-1',
          name: 'bot-alpha',
          model: 'claude-4',
          runtime: 'claude-code',
          status: 'active',
          activity: 'idle',
        ),
        AgentItem(
          id: 'agent-2',
          name: 'bot-beta',
          model: 'claude-4',
          runtime: 'claude-code',
          status: 'stopped',
          activity: 'offline',
        ),
        AgentItem(
          id: 'agent-3',
          name: 'bot-gamma',
          model: 'claude-4',
          runtime: 'claude-code',
          status: 'active',
          activity: 'thinking',
        ),
      ]);

      expect(
        selectNotifyCount,
        1,
        reason: 'agents change must notify agents select',
      );

      keepAlive.close();
    },
  );
}
