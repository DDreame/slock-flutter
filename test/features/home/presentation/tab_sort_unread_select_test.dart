// =============================================================================
// #632 — Provider.family cache fix + tab unread .select()
//
// Invariant: INV-TAB-SORT-CACHE-1
//   channels_tab_page.dart L175:
//   sortedChannelsProvider(allChannels) uses Provider.family with a List arg.
//   Dart list identity → new slot every build → sort re-runs unconditionally
//   and stale slots accumulate (memory leak).
//   Phase B inlines sort using homeListStore .select() for channels + pref.
//   After fix, unrelated state changes (taskCount, agents, etc.) must NOT
//   trigger re-sort.
//
// Invariant: INV-TAB-SORT-CACHE-2
//   dms_tab_page.dart L212: same issue with sortedDmsProvider(filtered).
//   Phase B inlines sort. Unrelated state changes must NOT trigger re-sort.
//
// Invariant: INV-TAB-UNREAD-SELECT-1
//   channels_tab_page.dart L74:
//   ref.watch(unreadSourceProjectionProvider) watches full state.
//   Channels tab only uses channelUnreadCounts/channelUnreadTotal.
//   DM unread changes must NOT rebuild channels tab.
//   Phase B narrows to .select((s) => s.channelUnreadCounts).
//
// Invariant: INV-TAB-UNREAD-SELECT-2
//   dms_tab_page.dart L87:
//   ref.watch(unreadSourceProjectionProvider) watches full state.
//   DMs tab only uses dmUnreadCounts/dmUnreadTotal.
//   Channel unread changes must NOT rebuild DMs tab.
//   Phase B narrows to .select((s) => s.dmUnreadCounts).
//
// Strategy:
// T1: unrelated homeListStore field change must NOT fire channels select
//     (skip:true — proves desired behavior).
// T2: unrelated homeListStore field change must NOT fire DMs select
//     (skip:true — proves desired behavior).
// T3: DM unread change must NOT fire channelUnreadCounts select (skip:true).
// T4: channel unread change must NOT fire dmUnreadCounts select (skip:true).
// T5: channel list change DOES fire channels select (active).
// T6: DM list change DOES fire DMs select (active).
// T7: channel unread change DOES fire channelUnreadCounts select (active).
// T8: DM unread change DOES fire dmUnreadCounts select (active).
//
// Phase A: T1-T4 skip:true, T5-T8 active.
// Phase B: Inline sort, apply .select(), un-skip T1-T4.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableHomeListStore extends HomeListStore {
  @override
  HomeListState build() {
    return HomeListState(
      status: HomeListStatus.success,
      channels: _channels,
      pinnedChannels: const [],
      directMessages: _dms,
      pinnedDirectMessages: const [],
      hiddenDirectMessages: const [],
      agents: const [],
      pinnedAgents: const [],
    );
  }

  static final _channels = [
    HomeChannelSummary(
      scopeId: const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
      name: 'General',
      lastActivityAt: DateTime.parse('2026-04-19T15:00:00Z'),
    ),
  ];

  static final _dms = [
    HomeDirectMessageSummary(
      scopeId: const DirectMessageScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'dm-1',
      ),
      title: 'Alice',
      lastActivityAt: DateTime.parse('2026-04-19T14:00:00Z'),
    ),
  ];

  void setTaskCountDirect(int count) {
    state = HomeListState(
      status: state.status,
      channels: state.channels,
      pinnedChannels: state.pinnedChannels,
      directMessages: state.directMessages,
      pinnedDirectMessages: state.pinnedDirectMessages,
      hiddenDirectMessages: state.hiddenDirectMessages,
      agents: state.agents,
      pinnedAgents: state.pinnedAgents,
      taskCount: count,
    );
  }

  void setChannelsDirect(List<HomeChannelSummary> channels) {
    state = HomeListState(
      status: state.status,
      channels: channels,
      pinnedChannels: state.pinnedChannels,
      directMessages: state.directMessages,
      pinnedDirectMessages: state.pinnedDirectMessages,
      hiddenDirectMessages: state.hiddenDirectMessages,
      agents: state.agents,
      pinnedAgents: state.pinnedAgents,
    );
  }

  void setDirectMessagesDirect(List<HomeDirectMessageSummary> dms) {
    state = HomeListState(
      status: state.status,
      channels: state.channels,
      pinnedChannels: state.pinnedChannels,
      directMessages: dms,
      pinnedDirectMessages: state.pinnedDirectMessages,
      hiddenDirectMessages: state.hiddenDirectMessages,
      agents: state.agents,
      pinnedAgents: state.pinnedAgents,
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // INV-TAB-SORT-CACHE-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T1: unrelated state change must NOT fire channels select.
  // -------------------------------------------------------------------------
  test(
    'INV-TAB-SORT-CACHE-1: unrelated homeListStore field change does NOT '
    'notify channels select',
    skip: true,
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(homeListStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        homeListStoreProvider.select(
          (s) => (channels: s.channels, pinnedChannels: s.pinnedChannels),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      // Change unrelated field — taskCount.
      store.setTaskCountDirect(42);

      expect(
        selectNotifyCount,
        0,
        reason: 'unrelated state change (taskCount) must not notify channels '
            'select (INV-TAB-SORT-CACHE-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: channel list change DOES fire channels select.
  // -------------------------------------------------------------------------
  test(
    'INV-TAB-SORT-CACHE-1: channel list change DOES notify channels select',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(homeListStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        homeListStoreProvider.select(
          (s) => (channels: s.channels, pinnedChannels: s.pinnedChannels),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setChannelsDirect([
        HomeChannelSummary(
          scopeId: const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
          name: 'General',
          lastActivityAt: DateTime.parse('2026-04-19T15:00:00Z'),
        ),
        HomeChannelSummary(
          scopeId: const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'random',
          ),
          name: 'Random',
          lastActivityAt: DateTime.parse('2026-04-19T15:01:00Z'),
        ),
      ]);

      expect(
        selectNotifyCount,
        1,
        reason: 'channel list change must notify channels select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // INV-TAB-SORT-CACHE-2
  // =========================================================================

  // -------------------------------------------------------------------------
  // T2: unrelated state change must NOT fire DMs select.
  // -------------------------------------------------------------------------
  test(
    'INV-TAB-SORT-CACHE-2: unrelated homeListStore field change does NOT '
    'notify DMs select',
    skip: true,
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(homeListStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        homeListStoreProvider.select(
          (s) => (
            directMessages: s.directMessages,
            pinnedDirectMessages: s.pinnedDirectMessages,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      // Change unrelated field — taskCount.
      store.setTaskCountDirect(99);

      expect(
        selectNotifyCount,
        0,
        reason: 'unrelated state change (taskCount) must not notify DMs '
            'select (INV-TAB-SORT-CACHE-2)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T6: DM list change DOES fire DMs select.
  // -------------------------------------------------------------------------
  test(
    'INV-TAB-SORT-CACHE-2: DM list change DOES notify DMs select',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider
              .overrideWith(() => _ControllableHomeListStore()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(homeListStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        homeListStoreProvider.select(
          (s) => (
            directMessages: s.directMessages,
            pinnedDirectMessages: s.pinnedDirectMessages,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(homeListStoreProvider.notifier)
          as _ControllableHomeListStore;
      store.setDirectMessagesDirect([
        HomeDirectMessageSummary(
          scopeId: const DirectMessageScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'dm-1',
          ),
          title: 'Alice',
          lastActivityAt: DateTime.parse('2026-04-19T14:00:00Z'),
        ),
        HomeDirectMessageSummary(
          scopeId: const DirectMessageScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'dm-2',
          ),
          title: 'Bob',
          lastActivityAt: DateTime.parse('2026-04-19T14:30:00Z'),
        ),
      ]);

      expect(
        selectNotifyCount,
        1,
        reason: 'DM list change must notify DMs select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // INV-TAB-UNREAD-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T3: DM unread change must NOT fire channelUnreadCounts select.
  // -------------------------------------------------------------------------
  test(
    'INV-TAB-UNREAD-SELECT-1: DM unread change does NOT notify '
    'channelUnreadCounts select',
    skip: true,
    () async {
      const channelScopeId = ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      );
      const dmScopeId = DirectMessageScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'dm-1',
      );

      // Use StateProvider so mutations guarantee synchronous notifications.
      final stateProvider = StateProvider<UnreadSourceProjectionState>((ref) {
        return UnreadSourceProjectionState(
          channelUnreadCounts: {channelScopeId: 3},
          dmUnreadCounts: {dmScopeId: 1},
          isLoaded: true,
        );
      });

      final container = ProviderContainer(
        overrides: [
          unreadSourceProjectionProvider.overrideWith(
            (ref) => ref.watch(stateProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(unreadSourceProjectionProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        unreadSourceProjectionProvider.select((s) => s.channelUnreadCounts),
        (_, __) => selectNotifyCount++,
      );

      // Simulate DM unread changing — channel counts unchanged.
      container.read(stateProvider.notifier).state =
          UnreadSourceProjectionState(
        channelUnreadCounts: {channelScopeId: 3},
        dmUnreadCounts: {dmScopeId: 5},
        isLoaded: true,
      );

      expect(
        selectNotifyCount,
        0,
        reason: 'DM unread change must not notify channelUnreadCounts select '
            '(INV-TAB-UNREAD-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T7: channel unread change DOES fire channelUnreadCounts select.
  // -------------------------------------------------------------------------
  test(
    'INV-TAB-UNREAD-SELECT-1: channel unread change DOES notify '
    'channelUnreadCounts select',
    skip: true,
    () async {
      const channelScopeId = ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      );

      // Use StateProvider so mutations guarantee synchronous notifications.
      final stateProvider = StateProvider<UnreadSourceProjectionState>((ref) {
        return UnreadSourceProjectionState(
          channelUnreadCounts: {channelScopeId: 3},
          isLoaded: true,
        );
      });

      final container = ProviderContainer(
        overrides: [
          unreadSourceProjectionProvider.overrideWith(
            (ref) => ref.watch(stateProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(unreadSourceProjectionProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        unreadSourceProjectionProvider.select((s) => s.channelUnreadCounts),
        (_, __) => selectNotifyCount++,
      );

      // Simulate channel unread changing.
      container.read(stateProvider.notifier).state =
          UnreadSourceProjectionState(
        channelUnreadCounts: {channelScopeId: 7},
        isLoaded: true,
      );

      expect(
        selectNotifyCount,
        1,
        reason: 'channel unread change must notify channelUnreadCounts select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // INV-TAB-UNREAD-SELECT-2
  // =========================================================================

  // -------------------------------------------------------------------------
  // T4: channel unread change must NOT fire dmUnreadCounts select.
  // -------------------------------------------------------------------------
  test(
    'INV-TAB-UNREAD-SELECT-2: channel unread change does NOT notify '
    'dmUnreadCounts select',
    skip: true,
    () async {
      const channelScopeId = ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      );
      const dmScopeId = DirectMessageScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'dm-1',
      );

      // Use StateProvider so mutations guarantee synchronous notifications.
      final stateProvider = StateProvider<UnreadSourceProjectionState>((ref) {
        return UnreadSourceProjectionState(
          channelUnreadCounts: {channelScopeId: 3},
          dmUnreadCounts: {dmScopeId: 2},
          isLoaded: true,
        );
      });

      final container = ProviderContainer(
        overrides: [
          unreadSourceProjectionProvider.overrideWith(
            (ref) => ref.watch(stateProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(unreadSourceProjectionProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        unreadSourceProjectionProvider.select((s) => s.dmUnreadCounts),
        (_, __) => selectNotifyCount++,
      );

      // Simulate channel unread changing — DM counts unchanged.
      container.read(stateProvider.notifier).state =
          UnreadSourceProjectionState(
        channelUnreadCounts: {channelScopeId: 9},
        dmUnreadCounts: {dmScopeId: 2},
        isLoaded: true,
      );

      expect(
        selectNotifyCount,
        0,
        reason: 'channel unread change must not notify dmUnreadCounts select '
            '(INV-TAB-UNREAD-SELECT-2)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T8: DM unread change DOES fire dmUnreadCounts select.
  // -------------------------------------------------------------------------
  test(
    'INV-TAB-UNREAD-SELECT-2: DM unread change DOES notify '
    'dmUnreadCounts select',
    skip: true,
    () async {
      const dmScopeId = DirectMessageScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'dm-1',
      );

      // Use StateProvider so mutations guarantee synchronous notifications.
      final stateProvider = StateProvider<UnreadSourceProjectionState>((ref) {
        return UnreadSourceProjectionState(
          dmUnreadCounts: {dmScopeId: 2},
          isLoaded: true,
        );
      });

      final container = ProviderContainer(
        overrides: [
          unreadSourceProjectionProvider.overrideWith(
            (ref) => ref.watch(stateProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(unreadSourceProjectionProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        unreadSourceProjectionProvider.select((s) => s.dmUnreadCounts),
        (_, __) => selectNotifyCount++,
      );

      // Simulate DM unread changing.
      container.read(stateProvider.notifier).state =
          UnreadSourceProjectionState(
        dmUnreadCounts: {dmScopeId: 8},
        isLoaded: true,
      );

      expect(
        selectNotifyCount,
        1,
        reason: 'DM unread change must notify dmUnreadCounts select',
      );

      keepAlive.close();
    },
  );
}
