// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';

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
// INV-PIN-4:   pinned agents tracked separately from pinnedConversationOrder
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
          agents: _makeAgentItems(['agent-1', 'agent-2', 'agent-3']),
          sidebarOrder: const SidebarOrder(
            agentOrder: ['agent-3', 'agent-1', 'agent-2'],
            pinnedAgentIds: ['agent-1'],
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        // Flush tier-2 supplemental microtasks (agents load asynchronously
        // via unawaited _loadAndMergeSupplemental).
        await Future<void>.delayed(Duration.zero);
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
      'pinned agents tracked separately from pinnedConversationOrder (INV-PIN-4)',
      skip: true,
      () async {
        // Setup: channel A pinned, agent-1 pinned. pinnedOrder=[ch-a, agent-1].
        // _currentPinnedConversationIds() filters to channels+DMs only,
        // so agents never appear in pinnedConversationOrder by design.
        // Assert:
        //   pinnedConversationOrder = [ch-a] (agents excluded)
        //   pinnedAgents = [agent-1] (agents in their own list)
        final container = _buildContainer(
          snapshot: _snapshotWithAll(
            channelIds: ['ch-a'],
            dmIds: [],
            agentIds: ['agent-1'],
          ),
          agents: _makeAgentItems(['agent-1']),
          sidebarOrder: const SidebarOrder(
            channelOrder: ['ch-a'],
            pinnedChannelIds: ['ch-a'],
            pinnedOrder: ['ch-a', 'agent-1'],
            pinnedAgentIds: ['agent-1'],
          ),
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();
        // Flush tier-2 supplemental microtasks (agents load asynchronously
        // via unawaited _loadAndMergeSupplemental).
        await Future<void>.delayed(Duration.zero);
        final state = container.read(homeListStoreProvider);

        // pinnedConversationOrder only includes channels + DMs (not agents).
        expect(state.pinnedConversationOrder, contains('ch-a'));
        expect(state.pinnedConversationOrder, isNot(contains('agent-1')),
            reason: 'Agents must not appear in pinnedConversationOrder');
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
  // Test by rendering HomePage with known channels + tasks and
  // verifying the task row shows the resolved channel name text.
  // -----------------------------------------------------------------------

  group('_channelName correctness', () {
    testWidgets(
      'returns channel name when ID matches (INV-NAME-1)',
      skip: true,
      (tester) async {
        // Setup: Render HomePage with channel 'ch-1' named 'general'
        //        and a task with channelId='ch-1'.
        // Assert: The task row displays '#general' (resolved name),
        //         not '#ch-1' (raw ID).
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: _FakeHomeRepository(
              _snapshotWithChannels(['ch-1'], names: {'ch-1': 'general'}),
            ),
            tasksRepository: _FakeTasksRepository(tasks: [
              TaskItem(
                id: 'task-1',
                taskNumber: 1,
                title: 'Fix the login bug',
                status: 'todo',
                channelId: 'ch-1',
                channelType: 'channel',
                createdById: 'user-1',
                createdByName: 'Alice',
                createdByType: 'human',
                createdAt: DateTime.parse('2026-05-18T00:00:00Z'),
              ),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        // _channelName resolves 'ch-1' → 'general', rendered as '#general'.
        final taskRow = find.byKey(const ValueKey('task-item-task-1'));
        expect(taskRow, findsOneWidget, reason: 'Task row must be rendered');
        expect(
          find.descendant(of: taskRow, matching: find.text('#general')),
          findsOneWidget,
          reason: '_channelName must resolve ID to name (INV-NAME-1)',
        );
      },
    );

    testWidgets(
      'falls back to raw channelId when not found (INV-NAME-2)',
      skip: true,
      (tester) async {
        // Setup: Render HomePage with channel 'ch-1' only,
        //        but task has channelId='ch-unknown' (no match).
        // Assert: The task row displays '#ch-unknown' (raw fallback).
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: _FakeHomeRepository(
              _snapshotWithChannels(['ch-1']),
            ),
            tasksRepository: _FakeTasksRepository(tasks: [
              TaskItem(
                id: 'task-1',
                taskNumber: 1,
                title: 'Unknown channel task',
                status: 'todo',
                channelId: 'ch-unknown',
                channelType: 'channel',
                createdById: 'user-1',
                createdByName: 'Alice',
                createdByType: 'human',
                createdAt: DateTime.parse('2026-05-18T00:00:00Z'),
              ),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        // _channelName has no match → falls back to raw ID '#ch-unknown'.
        final taskRow = find.byKey(const ValueKey('task-item-task-1'));
        expect(taskRow, findsOneWidget, reason: 'Task row must be rendered');
        expect(
          find.descendant(of: taskRow, matching: find.text('#ch-unknown')),
          findsOneWidget,
          reason: '_channelName must fall back to raw ID (INV-NAME-2)',
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
  // workspace; agent data comes from the agents parameter in
  // _buildContainer.
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

List<AgentItem> _makeAgentItems(List<String> ids) {
  return [
    for (final id in ids)
      AgentItem(
        id: id,
        name: id,
        model: 'test-model',
        runtime: 'test',
        status: 'active',
        activity: 'idle',
      ),
  ];
}

// ---------------------------------------------------------------------------
// Helpers — ProviderContainer factory (unit tests)
// ---------------------------------------------------------------------------

ProviderContainer _buildContainer({
  required HomeWorkspaceSnapshot snapshot,
  SidebarOrder sidebarOrder = const SidebarOrder(),
  List<AgentItem> agents = const [],
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
      agentsRepositoryProvider.overrideWithValue(
        _FakeAgentsRepository(agents: agents),
      ),
      tasksRepositoryProvider.overrideWithValue(
        const _FakeTasksRepository(),
      ),
      threadRepositoryProvider.overrideWithValue(
        const _FakeThreadRepository(),
      ),
      homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
    ],
  );
}

// ---------------------------------------------------------------------------
// Helpers — Widget test infrastructure (for _channelName tests)
// ---------------------------------------------------------------------------

Widget _buildApp({
  required GoRouter router,
  required HomeRepository homeRepository,
  TasksRepository tasksRepository = const _FakeTasksRepository(),
}) {
  return ProviderScope(
    overrides: [
      appLocalizationsProvider.overrideWithValue(
        lookupAppLocalizations(const Locale('en')),
      ),
      activeServerScopeIdProvider.overrideWithValue(_serverId),
      homeRepositoryProvider.overrideWithValue(homeRepository),
      serverListRepositoryProvider.overrideWithValue(
        const _FakeServerListRepository(),
      ),
      sidebarOrderRepositoryProvider.overrideWithValue(
        const _FakeSidebarOrderRepository(),
      ),
      agentsRepositoryProvider.overrideWithValue(
        const _FakeAgentsRepository(),
      ),
      tasksRepositoryProvider.overrideWithValue(tasksRepository),
      threadRepositoryProvider.overrideWithValue(
        const _FakeThreadRepository(),
      ),
      inboxRepositoryProvider.overrideWithValue(
        const _FakeInboxRepository(),
      ),
      homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
      agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      homeNowProvider.overrideWithValue(
        DateTime.parse('2026-05-18T00:00:00Z'),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/servers/:serverId/tasks',
        builder: (context, state) => const Scaffold(body: Placeholder()),
      ),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId',
        builder: (context, state) => const Scaffold(body: Placeholder()),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:dmId',
        builder: (context, state) => const Scaffold(body: Placeholder()),
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
  const _FakeSidebarOrderRepository({
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

class _FakeAgentsRepository implements AgentsRepository {
  const _FakeAgentsRepository({this.agents = const []});

  final List<AgentItem> agents;

  @override
  Future<List<AgentItem>> listAgents() async => agents;

  @override
  Future<void> startAgent(String agentId) async {}

  @override
  Future<void> stopAgent(String agentId) async {}

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {}

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      const [];
}

class _FakeTasksRepository implements TasksRepository {
  const _FakeTasksRepository({this.tasks = const []});

  final List<TaskItem> tasks;

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async => tasks;

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      [];

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {}

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async =>
      throw UnimplementedError();
}

class _FakeThreadRepository implements ThreadRepository {
  const _FakeThreadRepository();

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async =>
      const [];

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) =>
      throw UnimplementedError();

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}

class _FakeServerListRepository implements ServerListRepository {
  const _FakeServerListRepository();

  @override
  Future<List<ServerSummary>> loadServers() async => const [];
}

class _FakeInboxRepository implements InboxRepository {
  const _FakeInboxRepository();

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async =>
      const InboxResponse(
        items: [],
        totalCount: 0,
        totalUnreadCount: 0,
        hasMore: false,
      );

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

// ---------------------------------------------------------------------------
// String extension for capitalize (test-only helper)
// ---------------------------------------------------------------------------
extension _StringCapitalize on String {
  String capitalize() =>
      length == 0 ? this : '${this[0].toUpperCase()}${substring(1)}';
}
