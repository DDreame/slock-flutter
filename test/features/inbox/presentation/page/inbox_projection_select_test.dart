import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

// ---------------------------------------------------------------------------
// #512: Projection select() 精准订阅优化 — Phase A (test-only)
//
// BUG: inboxProjectionProvider and unreadSourceProjectionProvider watch
// the entire homeListStoreProvider. Tier-2 loads (agents, tasks, machines,
// threads) each emit a state update that triggers a full projection rebuild
// even though _visibilityContext() only reads channels + DMs + status.
// Result: 4-6 unnecessary rebuilds per app startup.
//
// Invariants:
//   INV-PROJ-OPT-1: Inbox projection rebuild count ≤ 2 during startup
//                    (initial + final success).
//   INV-PROJ-OPT-2: Tier-2 loads (agents/tasks/machines) must NOT trigger
//                    inbox projection rebuild.
//   INV-PROJ-OPT-3: Projection data correctness unchanged — select()
//                    results must match full watch results.
//
// Tests 1 & 3: skip: true until Phase B applies select() optimization.
// Test 2: passes on current codebase (channel/DM changes update correctly).
// ---------------------------------------------------------------------------

void main() {
  const serverId = ServerScopeId('server-1');

  const channelGeneral = ChannelScopeId(
    serverId: serverId,
    value: 'ch-general',
  );
  const channelRandom = ChannelScopeId(
    serverId: serverId,
    value: 'ch-random',
  );
  const dmAlice = DirectMessageScopeId(
    serverId: serverId,
    value: 'dm-alice',
  );

  // -----------------------------------------------------------------------
  // 1. Tier-2 homeListStore changes must NOT trigger projection rebuild
  //
  // Simulates app startup: homeListStore emits multiple state updates
  // as tier-2 data loads (agents → tasks → machines → threads).
  // Projection should only rebuild when channels/DMs/status change.
  //
  // Phase B: ref.watch(homeListStoreProvider) → ref.watch(...select(...))
  // -----------------------------------------------------------------------
  test(
    'inboxProjectionProvider: tier-2 homeListStore changes do not '
    'trigger rebuild (INV-PROJ-OPT-2)',
    skip: true,
    () {
      final homeStore = _ControllableHomeListStore(const HomeListState(
        status: HomeListStatus.success,
        channels: [
          HomeChannelSummary(scopeId: channelGeneral, name: 'general'),
        ],
      ));
      final inboxStore = _ControllableInboxStore(const InboxState(
        status: InboxStatus.success,
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-general',
            channelName: 'general',
            unreadCount: 3,
          ),
        ],
      ));

      final container = ProviderContainer(overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        inboxStoreProvider.overrideWith(() => inboxStore),
        homeListStoreProvider.overrideWith(() => homeStore),
      ]);
      addTearDown(container.dispose);

      // Initial read — triggers first build.
      final initial = container.read(inboxProjectionProvider);
      expect(initial, hasLength(1), reason: 'Initial projection must exist');

      // Count subsequent rebuilds via listen().
      var rebuildCount = 0;
      final sub = container.listen(inboxProjectionProvider, (prev, next) {
        rebuildCount++;
      });
      addTearDown(sub.close);

      // Simulate tier-2 loads: agents arrive.
      homeStore.setState(homeStore.state.copyWith(
        agents: const [
          AgentItem(
            id: 'agent-1',
            name: 'J1',
            model: 'opus',
            runtime: 'claude-code',
            status: 'active',
            activity: 'idle',
          ),
        ],
      ));

      // Simulate tier-2 loads: task count updates.
      homeStore.setState(homeStore.state.copyWith(taskCount: 5));

      // Simulate tier-2 loads: machine count updates.
      homeStore.setState(homeStore.state.copyWith(machineCount: 2));

      // Simulate tier-2 loads: thread count updates.
      homeStore.setState(homeStore.state.copyWith(threadCount: 3));

      // Currently FAILS: each tier-2 emit triggers a rebuild (4 rebuilds).
      // After Phase B select() optimization: 0 rebuilds (no relevant
      // fields changed).
      expect(rebuildCount, 0,
          reason: 'Tier-2 loads (agents/tasks/machines/threads) must NOT '
              'trigger inboxProjectionProvider rebuild — currently '
              'triggers $rebuildCount (INV-PROJ-OPT-2)');
    },
  );

  // -----------------------------------------------------------------------
  // 2. Channel/DM data changes must correctly update projection
  //
  // Passes on current codebase: visibility resolution uses channels/DMs,
  // so changes to those fields must propagate.
  // Also validates INV-PROJ-OPT-3 (correctness after optimization).
  // -----------------------------------------------------------------------
  test(
    'inboxProjectionProvider: channel/DM changes update projection '
    'correctly (INV-PROJ-OPT-3)',
    () {
      final homeStore = _ControllableHomeListStore(const HomeListState(
        status: HomeListStatus.success,
        channels: [
          HomeChannelSummary(scopeId: channelGeneral, name: 'general'),
        ],
      ));
      final inboxStore = _ControllableInboxStore(const InboxState(
        status: InboxStatus.success,
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-general',
            channelName: 'general',
            unreadCount: 3,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-random',
            channelName: 'random',
            unreadCount: 1,
          ),
          InboxItem(
            kind: InboxItemKind.dm,
            channelId: 'dm-alice',
            channelName: 'Alice',
            unreadCount: 2,
          ),
        ],
      ));

      final container = ProviderContainer(overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        inboxStoreProvider.overrideWith(() => inboxStore),
        homeListStoreProvider.overrideWith(() => homeStore),
      ]);
      addTearDown(container.dispose);

      // Initial: only ch-general is visible in homeList.
      final initial = container.read(inboxProjectionProvider);
      expect(initial, hasLength(3), reason: 'All 3 inbox items projected');

      // ch-general: visible (in homeList channels).
      final generalProj =
          initial.firstWhere((p) => p.channelId == 'ch-general');
      expect(generalProj.visibility, UnreadSourceVisibility.visible);

      // ch-random: hidden (not in homeList channels).
      final randomProj = initial.firstWhere((p) => p.channelId == 'ch-random');
      expect(randomProj.visibility, UnreadSourceVisibility.hidden);

      // dm-alice: hidden (not in homeList DMs).
      final dmProj = initial.firstWhere((p) => p.channelId == 'dm-alice');
      expect(dmProj.visibility, UnreadSourceVisibility.hidden);

      // Add ch-random and dm-alice to homeList.
      homeStore.setState(homeStore.state.copyWith(
        channels: const [
          HomeChannelSummary(scopeId: channelGeneral, name: 'general'),
          HomeChannelSummary(scopeId: channelRandom, name: 'random'),
        ],
        directMessages: const [
          HomeDirectMessageSummary(scopeId: dmAlice, title: 'Alice'),
        ],
      ));

      // After adding: all items should be visible.
      final updated = container.read(inboxProjectionProvider);
      expect(updated, hasLength(3));

      final updatedRandom =
          updated.firstWhere((p) => p.channelId == 'ch-random');
      expect(updatedRandom.visibility, UnreadSourceVisibility.visible,
          reason: 'ch-random must become visible after adding to homeList');

      final updatedDm = updated.firstWhere((p) => p.channelId == 'dm-alice');
      expect(updatedDm.visibility, UnreadSourceVisibility.visible,
          reason: 'dm-alice must become visible after adding to homeList');
    },
  );

  // -----------------------------------------------------------------------
  // 3. Startup simulation: projection rebuild count during full load
  //
  // Simulates realistic startup sequence:
  //   homeListStore: initial → loading → success (channels/DMs) →
  //     agents loaded → tasks loaded → machines loaded → threads loaded
  //
  // Projection should rebuild at most 2 times:
  //   1. When homeListStore reaches success (channels/DMs available)
  //   2. (Optional) If status changes again
  //
  // Currently rebuilds on every tier-2 emit (6+ rebuilds).
  //
  // Phase B: select() narrows subscription to relevant fields only.
  // -----------------------------------------------------------------------
  test(
    'inboxProjectionProvider: startup sequence rebuild count ≤ 2 '
    '(INV-PROJ-OPT-1)',
    skip: true,
    () {
      // Start with initial homeListStore (not yet loaded).
      final homeStore = _ControllableHomeListStore(const HomeListState());
      final inboxStore = _ControllableInboxStore(const InboxState(
        status: InboxStatus.success,
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-general',
            channelName: 'general',
            unreadCount: 3,
          ),
        ],
      ));

      final container = ProviderContainer(overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        inboxStoreProvider.overrideWith(() => inboxStore),
        homeListStoreProvider.overrideWith(() => homeStore),
      ]);
      addTearDown(container.dispose);

      // Initial read (homeListStore at initial status → empty projection).
      container.read(inboxProjectionProvider);

      // Count all rebuilds during startup.
      var rebuildCount = 0;
      final sub = container.listen(inboxProjectionProvider, (prev, next) {
        rebuildCount++;
      });
      addTearDown(sub.close);

      // Step 1: homeListStore → loading.
      homeStore.setState(homeStore.state.copyWith(
        status: HomeListStatus.loading,
      ));

      // Step 2: homeListStore → success with channels/DMs (tier-1 load).
      homeStore.setState(const HomeListState(
        status: HomeListStatus.success,
        channels: [
          HomeChannelSummary(scopeId: channelGeneral, name: 'general'),
        ],
      ));

      // Step 3: agents loaded (tier-2).
      homeStore.setState(homeStore.state.copyWith(
        agents: const [
          AgentItem(
            id: 'agent-1',
            name: 'J1',
            model: 'opus',
            runtime: 'claude-code',
            status: 'active',
            activity: 'idle',
          ),
        ],
      ));

      // Step 4: tasks loaded (tier-2).
      homeStore.setState(homeStore.state.copyWith(taskCount: 5));

      // Step 5: machines loaded (tier-2).
      homeStore.setState(homeStore.state.copyWith(machineCount: 2));

      // Step 6: threads loaded (tier-2).
      homeStore.setState(homeStore.state.copyWith(threadCount: 3));

      // Currently FAILS: rebuildCount is 6 (one per emit).
      // After Phase B: rebuildCount should be ≤ 2
      // (loading transition + success with channels).
      expect(rebuildCount, lessThanOrEqualTo(2),
          reason: 'Inbox projection must rebuild ≤ 2 times during startup '
              '(currently $rebuildCount — INV-PROJ-OPT-1)');
    },
  );
}

// ---------------------------------------------------------------------------
// Controllable stores — expose setState() for test-driven state changes.
// ---------------------------------------------------------------------------

class _ControllableInboxStore extends InboxStore {
  _ControllableInboxStore(this._initial);
  final InboxState _initial;

  @override
  InboxState build() => _initial;

  void setState(InboxState newState) {
    state = newState;
  }
}

class _ControllableHomeListStore extends HomeListStore {
  _ControllableHomeListStore(this._initial);
  final HomeListState _initial;

  @override
  HomeListState build() => _initial;

  void setState(HomeListState newState) {
    state = newState;
  }
}
