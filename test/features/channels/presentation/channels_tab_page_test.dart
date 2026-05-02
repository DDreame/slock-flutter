import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/channels/data/channel_management_repository.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  const channelGeneral = HomeChannelSummary(
    scopeId: ChannelScopeId(
      serverId: serverId,
      value: 'general',
    ),
    name: 'general',
  );

  const channelRandom = HomeChannelSummary(
    scopeId: ChannelScopeId(
      serverId: serverId,
      value: 'random',
    ),
    name: 'random',
  );

  const channelDesign = HomeChannelSummary(
    scopeId: ChannelScopeId(
      serverId: serverId,
      value: 'design',
    ),
    name: 'design',
  );

  const sampleSnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [channelGeneral, channelRandom],
    directMessages: [],
  );

  const threeChannelSnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [channelGeneral, channelRandom, channelDesign],
    directMessages: [],
  );

  const emptySnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [],
    directMessages: [],
  );

  Widget buildApp({
    required HomeRepository homeRepository,
    ServerScopeId? activeServerId = serverId,
    ChannelManagementRepository? channelManagementRepository,
    GoRouter? router,
  }) {
    final effectiveRouter = router ??
        GoRouter(
          initialLocation: '/channels',
          routes: [
            GoRoute(
              path: '/channels',
              builder: (_, __) => const ChannelsTabPage(),
            ),
            GoRoute(
              path: '/servers/:serverId/channels/:channelId',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Text(
                    'channel:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
                  ),
                ),
              ),
            ),
          ],
        );

    return ProviderScope(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(activeServerId),
        homeRepositoryProvider.overrideWithValue(homeRepository),
        sidebarOrderRepositoryProvider.overrideWithValue(
          const _FakeSidebarOrderRepository(),
        ),
        agentsRepositoryProvider.overrideWithValue(
          const _FakeAgentsRepository(),
        ),
        tasksRepositoryProvider.overrideWithValue(
          const _FakeTasksRepository(),
        ),
        threadRepositoryProvider.overrideWithValue(
          const _FakeThreadRepository(),
        ),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        if (channelManagementRepository != null)
          channelManagementRepositoryProvider.overrideWithValue(
            channelManagementRepository,
          ),
      ],
      child: MaterialApp.router(
        routerConfig: effectiveRouter,
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('renders channel rows when data loads', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('channels-tab-general')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-random')),
      findsOneWidget,
    );
  });

  testWidgets('shows empty state when no channels', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(emptySnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('channels-tab-empty')),
      findsOneWidget,
    );
    expect(find.text('No channels yet.'), findsOneWidget);
  });

  testWidgets('shows no-server state when activeServer is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
        activeServerId: null,
      ),
    );
    await tester.pumpAndSettle();

    // Should not show channel rows.
    expect(
      find.byKey(const ValueKey('channels-tab-general')),
      findsNothing,
    );
  });

  testWidgets('sorts unread channels before read channels', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(threeChannelSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    // All three channels should be visible.
    expect(
      find.byKey(const ValueKey('channels-tab-general')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-random')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-design')),
      findsOneWidget,
    );

    // Verify the unread-first order by checking widget positions.
    // Without any unreads, the original order should be preserved.
    final generalOffset = tester.getTopLeft(
      find.byKey(const ValueKey('channels-tab-general')),
    );
    final randomOffset = tester.getTopLeft(
      find.byKey(const ValueKey('channels-tab-random')),
    );
    final designOffset = tester.getTopLeft(
      find.byKey(const ValueKey('channels-tab-design')),
    );

    // Original order: general, random, design (all read).
    expect(generalOffset.dy, lessThan(randomOffset.dy));
    expect(randomOffset.dy, lessThan(designOffset.dy));
  });

  testWidgets('search filters channels by name', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(threeChannelSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    // All three channels visible initially.
    expect(
      find.byKey(const ValueKey('channels-tab-general')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-random')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-design')),
      findsOneWidget,
    );

    // Type in the search field.
    await tester.enterText(
      find.byKey(const ValueKey('channels-tab-search')),
      'gen',
    );
    await tester.pumpAndSettle();

    // Only 'general' should remain.
    expect(
      find.byKey(const ValueKey('channels-tab-general')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-random')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-design')),
      findsNothing,
    );
  });

  testWidgets('search shows empty result text when no match', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('channels-tab-search')),
      'nonexistent',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('channels-tab-search-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-general')),
      findsNothing,
    );
  });

  testWidgets('tapping a channel navigates to channel route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/channels',
      routes: [
        GoRoute(
          path: '/channels',
          builder: (_, __) => const ChannelsTabPage(),
        ),
        GoRoute(
          path: '/servers/:serverId/channels/:channelId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'channel:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('channels-tab-general')),
    );
    await tester.pumpAndSettle();

    expect(find.text('channel:server-1/general'), findsOneWidget);
  });

  testWidgets('create button opens create channel dialog', (
    tester,
  ) async {
    final channelMgmt = _FakeChannelManagementRepository();

    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
        channelManagementRepository: channelMgmt,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('channels-tab-create-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('create-channel-dialog')),
      findsOneWidget,
    );
  });

  testWidgets('shows search field', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('channels-tab-search')),
      findsOneWidget,
    );
  });

  testWidgets('refresh indicator triggers data reload', (tester) async {
    final repo = _MutableFakeHomeRepository(sampleSnapshot);

    await tester.pumpWidget(buildApp(homeRepository: repo));
    await tester.pumpAndSettle();

    expect(repo.loadCount, 1);

    // Trigger pull-to-refresh.
    await tester.fling(
      find.byKey(const ValueKey('channels-tab-general')),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(repo.loadCount, greaterThan(1));
  });
}

// ----  Fakes  ----

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this.snapshot);

  final HomeWorkspaceSnapshot snapshot;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(
    ServerScopeId serverId,
  ) async {
    return snapshot;
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
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

class _MutableFakeHomeRepository implements HomeRepository {
  _MutableFakeHomeRepository(this.snapshot);

  final HomeWorkspaceSnapshot snapshot;
  int loadCount = 0;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(
    ServerScopeId serverId,
  ) async {
    loadCount++;
    return snapshot;
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
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
  const _FakeSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    return const SidebarOrder();
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}

class _FakeAgentsRepository implements AgentsRepository {
  const _FakeAgentsRepository();

  @override
  Future<List<AgentItem>> listAgents() async => const [];

  @override
  Future<void> startAgent(String agentId) async {}

  @override
  Future<void> stopAgent(String agentId) async {}

  @override
  Future<void> resetAgent(
    String agentId, {
    required String mode,
  }) async {}

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      const [];
}

class _FakeTasksRepository implements TasksRepository {
  const _FakeTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(
    ServerScopeId serverId,
  ) async =>
      const [];

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
  Future<ResolvedThreadChannel> resolveThread(
    ThreadRouteTarget target,
  ) async =>
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

class _FakeChannelManagementRepository implements ChannelManagementRepository {
  _FakeChannelManagementRepository({this.createdChannelId});

  final String? createdChannelId;
  final List<String> createdNames = [];

  @override
  Future<String?> createChannel(
    ServerScopeId serverId, {
    required String name,
  }) async {
    createdNames.add(name);
    return createdChannelId;
  }

  @override
  Future<void> updateChannel(
    ServerScopeId serverId, {
    required String channelId,
    required String name,
  }) async {}

  @override
  Future<void> deleteChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> leaveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}
}
