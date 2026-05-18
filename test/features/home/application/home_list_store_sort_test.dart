// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';

// ---------------------------------------------------------------------------
// #561 Phase A — HomeListStore Hot Path Optimization
//
// Sort correctness, pinned order stability, channelName resolution.
//
// INV-SORT-1:  channels sorted by sidebar channelOrder
// INV-SORT-2:  pinned channels sorted by pinnedOrder, not channelOrder
// INV-SORT-3:  DMs sorted by sidebar dmOrder
// INV-SORT-4:  hidden DMs excluded from visible + pinned lists
// INV-SORT-5:  pinned DMs exclude hidden IDs
// INV-SORT-6:  agents sorted by agentOrder, pinned split correct
// INV-PIN-1:   preserves manual pinnedOrder for existing pinned items
// INV-PIN-2:   newly pinned channel appended after existing pinnedOrder
// INV-PIN-3:   newly pinned DM appended, hidden DM excluded
// INV-PIN-4:   newly pinned agent appended after channels+DMs
// INV-PIN-5:   duplicate protection (contains check)
// INV-NAME-1:  _channelName returns name when ID matches
// INV-NAME-2:  _channelName falls back to raw channelId when not found
//
// Phase A — all tests skip: true.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // Group 1 — _emitPersonalizedState sort correctness
  // -----------------------------------------------------------------------

  group('_emitPersonalizedState sort correctness', () {
    test(
      'channels sorted by sidebar channelOrder (INV-SORT-1)',
      skip: true,
      () async {
        // Setup: 3 channels [A, B, C], channelOrder = [C, A, B].
        // Assert: state.channels follows [C, A, B] after load.
        final container = _buildContainer(
          snapshot: _snapshotWithChannels(['ch-a', 'ch-b', 'ch-c']),
          sidebarOrder: const SidebarOrder(
            channelOrder: ['ch-c', 'ch-a', 'ch-b'],
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final state = container.read(homeListStoreProvider);

        expect(state.status, HomeListStatus.success);
        expect(
          state.channels.map((c) => c.scopeId.value).toList(),
          ['ch-c', 'ch-a', 'ch-b'],
        );
      },
    );

    test(
      'pinned channels sorted by pinnedOrder, not channelOrder (INV-SORT-2)',
      skip: true,
      () async {
        // Setup: channels [A, B, C], channelOrder=[A,B,C],
        // pinnedChannelIds=[A,C], pinnedOrder=[C,A].
        // Assert: state.pinnedChannels = [C, A], state.channels = [B].
        final container = _buildContainer(
          snapshot: _snapshotWithChannels(['ch-a', 'ch-b', 'ch-c']),
          sidebarOrder: const SidebarOrder(
            channelOrder: ['ch-a', 'ch-b', 'ch-c'],
            pinnedChannelIds: ['ch-a', 'ch-c'],
            pinnedOrder: ['ch-c', 'ch-a'],
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final state = container.read(homeListStoreProvider);

        expect(
          state.pinnedChannels.map((c) => c.scopeId.value).toList(),
          ['ch-c', 'ch-a'],
        );
        expect(
          state.channels.map((c) => c.scopeId.value).toList(),
          ['ch-b'],
        );
      },
    );

    test(
      'DMs sorted by sidebar dmOrder (INV-SORT-3)',
      skip: true,
      () async {
        // Setup: DMs [alice, bob, carol], dmOrder=[carol, alice, bob].
        // Assert: state.directMessages follows dmOrder.
        final container = _buildContainer(
          snapshot: _snapshotWithDms(['dm-alice', 'dm-bob', 'dm-carol']),
          sidebarOrder: const SidebarOrder(
            dmOrder: ['dm-carol', 'dm-alice', 'dm-bob'],
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final state = container.read(homeListStoreProvider);

        expect(
          state.directMessages.map((d) => d.scopeId.value).toList(),
          ['dm-carol', 'dm-alice', 'dm-bob'],
        );
      },
    );

    test(
      'hidden DMs excluded from visible + pinned lists (INV-SORT-4)',
      skip: true,
      () async {
        // Setup: DMs [alice, bob], hiddenDmIds=[dm-alice].
        // Assert: state.directMessages has only bob,
        //         state.hiddenDirectMessages has alice.
        final container = _buildContainer(
          snapshot: _snapshotWithDms(['dm-alice', 'dm-bob']),
          sidebarOrder: const SidebarOrder(
            hiddenDmIds: ['dm-alice'],
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final state = container.read(homeListStoreProvider);

        expect(
          state.directMessages.map((d) => d.scopeId.value).toList(),
          ['dm-bob'],
        );
        expect(
          state.hiddenDirectMessages.map((d) => d.scopeId.value).toList(),
          ['dm-alice'],
        );
        // Hidden DM must not appear in pinned lists either.
        expect(state.pinnedDirectMessages, isEmpty);
      },
    );

    test(
      'pinned DMs exclude hidden IDs (INV-SORT-5)',
      skip: true,
      () async {
        // Setup: DMs [alice, bob], pinnedChannelIds=[dm-alice, dm-bob],
        // hiddenDmIds=[dm-alice].
        // Assert: state.pinnedDirectMessages has only bob.
        //         state.hiddenDirectMessages has alice.
        final container = _buildContainer(
          snapshot: _snapshotWithDms(['dm-alice', 'dm-bob']),
          sidebarOrder: const SidebarOrder(
            pinnedChannelIds: ['dm-alice', 'dm-bob'],
            pinnedOrder: ['dm-alice', 'dm-bob'],
            hiddenDmIds: ['dm-alice'],
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final state = container.read(homeListStoreProvider);

        expect(
          state.pinnedDirectMessages.map((d) => d.scopeId.value).toList(),
          ['dm-bob'],
        );
        expect(
          state.hiddenDirectMessages.map((d) => d.scopeId.value).toList(),
          ['dm-alice'],
        );
      },
    );

    test(
      'agents sorted by agentOrder, pinned split correct (INV-SORT-6)',
      skip: true,
      () async {
        // Setup: agents [a1, a2, a3], agentOrder=[a3,a1,a2],
        // pinnedAgentIds=[a1].
        // Assert: state.pinnedAgents=[a1], state.agents=[a3,a2].
        final container = _buildContainer(
          snapshot: _snapshotWithAgents(['agent-1', 'agent-2', 'agent-3']),
          sidebarOrder: const SidebarOrder(
            agentOrder: ['agent-3', 'agent-1', 'agent-2'],
            pinnedAgentIds: ['agent-1'],
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final state = container.read(homeListStoreProvider);

        expect(
          state.pinnedAgents.map((a) => a.id).toList(),
          ['agent-1'],
        );
        expect(
          state.agents.map((a) => a.id).toList(),
          ['agent-3', 'agent-2'],
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // Group 2 — _currentPinnedConversationIds order stability
  // -----------------------------------------------------------------------

  group('_currentPinnedConversationIds order stability', () {
    test(
      'preserves manual pinnedOrder for existing pinned items (INV-PIN-1)',
      skip: true,
      () async {
        // Setup: channels [A, B], both pinned, pinnedOrder=[B, A].
        // Assert: state.pinnedConversationOrder starts with [B, A].
        final container = _buildContainer(
          snapshot: _snapshotWithChannels(['ch-a', 'ch-b']),
          sidebarOrder: const SidebarOrder(
            channelOrder: ['ch-a', 'ch-b'],
            pinnedChannelIds: ['ch-a', 'ch-b'],
            pinnedOrder: ['ch-b', 'ch-a'],
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final state = container.read(homeListStoreProvider);

        expect(
          state.pinnedConversationOrder,
          ['ch-b', 'ch-a'],
        );
      },
    );

    test(
      'newly pinned channel appended after existing pinnedOrder (INV-PIN-2)',
      skip: true,
      () async {
        // Setup: channels [A, B, C], A pinned initially (pinnedOrder=[A]).
        // Then pin C. Assert: pinnedConversationOrder = [A, C].
        final container = _buildContainer(
          snapshot: _snapshotWithChannels(['ch-a', 'ch-b', 'ch-c']),
          sidebarOrder: const SidebarOrder(
            channelOrder: ['ch-a', 'ch-b', 'ch-c'],
            pinnedChannelIds: ['ch-a'],
            pinnedOrder: ['ch-a'],
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();

        // Pin ch-c via store method.
        await container.read(homeListStoreProvider.notifier).pinChannel(
              const ChannelScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'ch-c',
              ),
            );
        final state = container.read(homeListStoreProvider);

        expect(state.pinnedConversationOrder, contains('ch-a'));
        expect(state.pinnedConversationOrder, contains('ch-c'));
        // ch-a should come before ch-c (existing before newly added).
        expect(
          state.pinnedConversationOrder.indexOf('ch-a'),
          lessThan(state.pinnedConversationOrder.indexOf('ch-c')),
        );
      },
    );

    test(
      'newly pinned DM appended, hidden DM excluded (INV-PIN-3)',
      skip: true,
      () async {
        // Setup: DMs [alice, bob, carol], hiddenDmIds=[dm-carol].
        // Pin bob and carol. Assert: pinnedConversationOrder includes bob
        // but NOT carol (carol is hidden).
        final container = _buildContainer(
          snapshot: _snapshotWithDms(['dm-alice', 'dm-bob', 'dm-carol']),
          sidebarOrder: const SidebarOrder(
            pinnedChannelIds: ['dm-bob', 'dm-carol'],
            pinnedOrder: ['dm-bob', 'dm-carol'],
            hiddenDmIds: ['dm-carol'],
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final state = container.read(homeListStoreProvider);

        expect(state.pinnedConversationOrder, contains('dm-bob'));
        expect(state.pinnedConversationOrder, isNot(contains('dm-carol')));
      },
    );

    test(
      'newly pinned agent appended after channels+DMs (INV-PIN-4)',
      skip: true,
      () async {
        // Setup: channel A pinned, agent-1 pinned. pinnedOrder=[ch-a, agent-1].
        // Assert: pinnedConversationOrder = [ch-a] only (agents don't appear
        // in pinnedConversationOrder — only in pinnedOrder through
        // _currentPinnedOrder). Verify pinnedAgents list contains agent-1.
        final container = _buildContainer(
          snapshot: _snapshotWithAll(
            channelIds: ['ch-a'],
            dmIds: [],
            agentIds: ['agent-1'],
          ),
          sidebarOrder: const SidebarOrder(
            channelOrder: ['ch-a'],
            pinnedChannelIds: ['ch-a'],
            pinnedOrder: ['ch-a', 'agent-1'],
            pinnedAgentIds: ['agent-1'],
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final state = container.read(homeListStoreProvider);

        // pinnedConversationOrder only includes channels + DMs (not agents).
        expect(state.pinnedConversationOrder, contains('ch-a'));
        // Agent is in pinnedAgents list, not in pinnedConversationOrder.
        expect(state.pinnedAgents.map((a) => a.id).toList(), ['agent-1']);
      },
    );

    test(
      'duplicate protection — same ID pinned in multiple categories appears once (INV-PIN-5)',
      skip: true,
      () async {
        // Setup: channels [A, B], both pinned, pinnedOrder has A twice: [A, B, A].
        // Assert: pinnedConversationOrder has A only once.
        final container = _buildContainer(
          snapshot: _snapshotWithChannels(['ch-a', 'ch-b']),
          sidebarOrder: const SidebarOrder(
            channelOrder: ['ch-a', 'ch-b'],
            pinnedChannelIds: ['ch-a', 'ch-b'],
            pinnedOrder: ['ch-a', 'ch-b', 'ch-a'],
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final state = container.read(homeListStoreProvider);

        // Each ID appears at most once.
        final order = state.pinnedConversationOrder;
        expect(order.toSet().length, order.length,
            reason: 'No duplicate IDs in pinnedConversationOrder');
      },
    );
  });

  // -----------------------------------------------------------------------
  // Group 3 — _channelName correctness
  //
  // _channelName is a private method on _HomeTasksSection widget.
  // Test by rendering the widget with known channels + tasks and
  // verifying the task row shows the resolved channel name.
  // -----------------------------------------------------------------------

  group('_channelName correctness', () {
    test(
      'returns channel name when ID matches (INV-NAME-1)',
      skip: true,
      () async {
        // Setup: HomeListStore loaded with channel 'ch-1' named 'general'.
        //        Task with channelId='ch-1'.
        // Assert: Rendered task row shows 'general' (not 'ch-1').
        //
        // Phase B will render _HomeTasksSection widget with known channels
        // list and task list, then assert the channel name text.
        final container = _buildContainer(
          snapshot: _snapshotWithChannels(['ch-1'], names: {'ch-1': 'general'}),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final state = container.read(homeListStoreProvider);

        // Verify the channel is available for name resolution.
        expect(state.channels.first.name, 'general');
      },
    );

    test(
      'falls back to raw channelId when not found (INV-NAME-2)',
      skip: true,
      () async {
        // Setup: HomeListStore loaded with channel 'ch-1' only.
        //        Task with channelId='ch-unknown'.
        // Assert: Rendered task row shows 'ch-unknown' (raw ID fallback).
        //
        // Phase B will render _HomeTasksSection and assert fallback.
        final container = _buildContainer(
          snapshot: _snapshotWithChannels(['ch-1']),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        final state = container.read(homeListStoreProvider);

        // Verify no channel named 'ch-unknown' exists.
        expect(
          state.channels.every((c) => c.scopeId.value != 'ch-unknown'),
          isTrue,
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers — snapshot builders
// ---------------------------------------------------------------------------

const _serverId = ServerScopeId('server-1');

HomeWorkspaceSnapshot _snapshotWithChannels(
  List<String> channelIds, {
  Map<String, String> names = const {},
}) {
  return HomeWorkspaceSnapshot(
    serverId: _serverId,
    channels: [
      for (final id in channelIds)
        HomeChannelSummary(
          scopeId: ChannelScopeId(serverId: _serverId, value: id),
          name: names[id] ?? id,
        ),
    ],
    directMessages: const [],
  );
}

HomeWorkspaceSnapshot _snapshotWithDms(List<String> dmIds) {
  return HomeWorkspaceSnapshot(
    serverId: _serverId,
    channels: const [],
    directMessages: [
      for (final id in dmIds)
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(serverId: _serverId, value: id),
          title: id.replaceFirst('dm-', '').capitalize(),
        ),
    ],
  );
}

// ignore: unused_element
HomeWorkspaceSnapshot _snapshotWithAgents(List<String> agentIds) {
  // Agents are loaded separately via agentsRepositoryProvider,
  // not from the workspace snapshot. This helper returns an empty
  // workspace; Phase B will add agentsRepositoryProvider override.
  return const HomeWorkspaceSnapshot(
    serverId: _serverId,
    channels: [],
    directMessages: [],
  );
}

HomeWorkspaceSnapshot _snapshotWithAll({
  required List<String> channelIds,
  required List<String> dmIds,
  required List<String> agentIds,
}) {
  return HomeWorkspaceSnapshot(
    serverId: _serverId,
    channels: [
      for (final id in channelIds)
        HomeChannelSummary(
          scopeId: ChannelScopeId(serverId: _serverId, value: id),
          name: id,
        ),
    ],
    directMessages: [
      for (final id in dmIds)
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(serverId: _serverId, value: id),
          title: id.replaceFirst('dm-', '').capitalize(),
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Helpers — ProviderContainer factory
// ---------------------------------------------------------------------------

ProviderContainer _buildContainer({
  required HomeWorkspaceSnapshot snapshot,
  SidebarOrder sidebarOrder = const SidebarOrder(),
}) {
  return ProviderContainer(
    overrides: [
      activeServerScopeIdProvider.overrideWithValue(_serverId),
      homeRepositoryProvider.overrideWithValue(
        _FakeHomeRepository(snapshot),
      ),
      sidebarOrderRepositoryProvider.overrideWithValue(
        _FakeSidebarOrderRepository(sidebarOrder: sidebarOrder),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this.snapshot);

  final HomeWorkspaceSnapshot snapshot;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
  }

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    return snapshot;
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async {
    return summary;
  }

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  _FakeSidebarOrderRepository({
    this.sidebarOrder = const SidebarOrder(),
  });

  final SidebarOrder sidebarOrder;

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    return sidebarOrder;
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}

// ---------------------------------------------------------------------------
// String extension for capitalize (test-only helper)
// ---------------------------------------------------------------------------
extension _StringCapitalize on String {
  String capitalize() =>
      length == 0 ? this : '${this[0].toUpperCase()}${substring(1)}';
}
