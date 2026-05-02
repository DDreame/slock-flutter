import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/dms/presentation/page/dms_tab_page.dart';
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

void main() {
  const serverId = ServerScopeId('server-1');

  const dmAlice = HomeDirectMessageSummary(
    scopeId: DirectMessageScopeId(
      serverId: serverId,
      value: 'dm-alice',
    ),
    title: 'Alice',
  );

  const dmBob = HomeDirectMessageSummary(
    scopeId: DirectMessageScopeId(
      serverId: serverId,
      value: 'dm-bob',
    ),
    title: 'Bob',
  );

  const dmCharlie = HomeDirectMessageSummary(
    scopeId: DirectMessageScopeId(
      serverId: serverId,
      value: 'dm-charlie',
    ),
    title: 'Charlie',
  );

  const sampleSnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [],
    directMessages: [dmAlice, dmBob],
  );

  const threeDmSnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [],
    directMessages: [dmAlice, dmBob, dmCharlie],
  );

  const emptySnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [],
    directMessages: [],
  );

  Widget buildApp({
    required HomeRepository homeRepository,
    ServerScopeId? activeServerId = serverId,
    GoRouter? router,
  }) {
    final effectiveRouter = router ??
        GoRouter(
          initialLocation: '/dms',
          routes: [
            GoRoute(
              path: '/dms',
              builder: (_, __) => const DmsTabPage(),
            ),
            GoRoute(
              path: '/servers/:serverId/dms/:channelId',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Text(
                    'dm:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
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
        homeMachineCountLoaderProvider.overrideWithValue(
          (_) async => 0,
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

  testWidgets('renders DM rows when data loads', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-bob')),
      findsOneWidget,
    );
  });

  testWidgets('shows empty state when no DMs', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(emptySnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-empty')),
      findsOneWidget,
    );
    expect(find.text('No direct messages yet.'), findsOneWidget);
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

    expect(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
      findsNothing,
    );
  });

  testWidgets('preserves original order when all DMs are read', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(threeDmSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-bob')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-charlie')),
      findsOneWidget,
    );

    final aliceOffset = tester.getTopLeft(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
    );
    final bobOffset = tester.getTopLeft(
      find.byKey(const ValueKey('dms-tab-dm-bob')),
    );
    final charlieOffset = tester.getTopLeft(
      find.byKey(const ValueKey('dms-tab-dm-charlie')),
    );

    expect(aliceOffset.dy, lessThan(bobOffset.dy));
    expect(bobOffset.dy, lessThan(charlieOffset.dy));
  });

  testWidgets('search filters DMs by title', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(threeDmSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-bob')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-charlie')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('dms-tab-search')),
      'ali',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-bob')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-charlie')),
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
      find.byKey(const ValueKey('dms-tab-search')),
      'nonexistent',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-search-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
      findsNothing,
    );
  });

  testWidgets('tapping a DM navigates to DM route', (tester) async {
    final router = GoRouter(
      initialLocation: '/dms',
      routes: [
        GoRoute(
          path: '/dms',
          builder: (_, __) => const DmsTabPage(),
        ),
        GoRoute(
          path: '/servers/:serverId/dms/:channelId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'dm:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
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
      find.byKey(const ValueKey('dms-tab-dm-alice')),
    );
    await tester.pumpAndSettle();

    expect(find.text('dm:server-1/dm-alice'), findsOneWidget);
  });

  testWidgets('shows search field', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-search')),
      findsOneWidget,
    );
  });

  testWidgets('shows new message button', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-create-button')),
      findsOneWidget,
    );
  });

  testWidgets('refresh indicator triggers data reload', (
    tester,
  ) async {
    final repo = _MutableFakeHomeRepository(sampleSnapshot);

    await tester.pumpWidget(buildApp(homeRepository: repo));
    await tester.pumpAndSettle();

    expect(repo.loadCount, 1);

    await tester.fling(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
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
  ) async =>
      snapshot;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async =>
      summary;

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
  ) async =>
      null;

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async =>
      summary;

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
  Future<SidebarOrder> loadSidebarOrder(
    ServerScopeId serverId,
  ) async =>
      const SidebarOrder();

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
