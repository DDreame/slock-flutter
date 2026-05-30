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

/// Regression tests for Home page product scenarios:
/// - Task error card renders error UI with retry
/// - Agent grouping via shared projection
void main() {
  group('task error card regression', () {
    testWidgets('shows unavailable state when tasks fail to load',
        (tester) async {
      final router = _buildRouter();

      await tester.pumpWidget(
        _buildApp(
          router: router,
          homeRepository: const _FakeHomeRepository(_emptySnapshot),
          tasksRepository: const _FailingTasksRepository(),
        ),
      );
      await tester.pumpAndSettle();

      // Task unavailable state should be visible
      expect(
        find.byKey(const ValueKey('home-tasks-unavailable')),
        findsOneWidget,
        reason: 'Task error should show unavailable state, not silent empty',
      );

      // Error message should be visible
      expect(
        find.byIcon(Icons.error_outline),
        findsOneWidget,
        reason: 'Error icon should appear in unavailable state',
      );

      // Retry button should be visible
      expect(
        find.byIcon(Icons.refresh),
        findsOneWidget,
        reason: 'Retry button should appear in unavailable state',
      );

      // Empty state should NOT be shown
      expect(
        find.byKey(const ValueKey('home-tasks-empty')),
        findsNothing,
        reason: 'Empty state should not appear when tasks failed to load',
      );
    });

    testWidgets('retry button triggers home refresh', (tester) async {
      final router = _buildRouter();
      var loadCount = 0;

      await tester.pumpWidget(
        _buildApp(
          router: router,
          homeRepository: _CountingHomeRepository(
            snapshot: _emptySnapshot,
            onLoad: () => loadCount++,
          ),
          tasksRepository: const _FailingTasksRepository(),
        ),
      );
      await tester.pumpAndSettle();

      // Record load count after initial load
      final initialLoadCount = loadCount;

      // Tap retry
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      // Should have triggered another load cycle
      expect(loadCount, greaterThan(initialLoadCount),
          reason: 'Retry button should trigger home refresh');
    });

    testWidgets('shows empty state when tasks load succeeds with no items',
        (tester) async {
      final router = _buildRouter();

      await tester.pumpWidget(
        _buildApp(
          router: router,
          homeRepository: const _FakeHomeRepository(_emptySnapshot),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state should be visible (no tasks, no error)
      expect(
        find.byKey(const ValueKey('home-tasks-empty')),
        findsOneWidget,
        reason: 'Empty tasks state should appear when no tasks exist',
      );

      // Unavailable state should NOT appear
      expect(
        find.byKey(const ValueKey('home-tasks-unavailable')),
        findsNothing,
        reason: 'Unavailable state should not appear when load succeeds',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _emptySnapshot = HomeWorkspaceSnapshot(
  serverId: ServerScopeId('server-1'),
  channels: [],
  directMessages: [],
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp({
  required GoRouter router,
  required HomeRepository homeRepository,
  TasksRepository tasksRepository = const _FakeTasksRepository(),
}) {
  return ProviderScope(
    overrides: [
      activeServerScopeIdProvider.overrideWithValue(
        const ServerScopeId('server-1'),
      ),
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
        const _EmptyInboxRepository(),
      ),
      homeMachineCountLoaderProvider.overrideWithValue(
        (_) async => 0,
      ),
      agentsMachinesLoaderProvider.overrideWithValue(
        () async => const [],
      ),
      homeNowProvider.overrideWith(
        (ref) => Stream.value(DateTime(2026, 1, 1)),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
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
        path: '/servers/:serverId/agents',
        builder: (context, state) => const Scaffold(body: Text('agents')),
      ),
      GoRoute(
        path: '/servers/:serverId/tasks',
        builder: (context, state) => const Scaffold(body: Text('tasks')),
      ),
      GoRoute(
        path: '/servers/:serverId/unread',
        builder: (context, state) => const Scaffold(body: Text('unread')),
      ),
      GoRoute(
        path: '/servers/:serverId/search',
        builder: (context, state) => const Scaffold(body: Text('search')),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Scaffold(body: Text('settings')),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this._snapshot);
  final HomeWorkspaceSnapshot _snapshot;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async =>
      _snapshot;

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

class _CountingHomeRepository implements HomeRepository {
  _CountingHomeRepository({
    required this.snapshot,
    required this.onLoad,
  });
  final HomeWorkspaceSnapshot snapshot;
  final VoidCallback onLoad;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    onLoad();
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

class _FakeTasksRepository implements TasksRepository {
  const _FakeTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async =>
      const [];

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      const [];

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

class _FailingTasksRepository implements TasksRepository {
  const _FailingTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    throw const ServerFailure(
      statusCode: 500,
      message: 'Internal server error',
    );
  }

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      throw UnimplementedError();

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
  }) async =>
      throw UnimplementedError();

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

class _FakeAgentsRepository implements AgentsRepository {
  const _FakeAgentsRepository();

  @override
  Future<List<AgentItem>> listAgents() async => const [];

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

class _FakeServerListRepository implements ServerListRepository {
  const _FakeServerListRepository();

  @override
  Future<List<ServerSummary>> loadServers() async => const [];
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async =>
      const SidebarOrder();

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
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
  Future<void> unfollowThread(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadUndone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}

class _EmptyInboxRepository implements InboxRepository {
  const _EmptyInboxRepository();

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    return const InboxResponse(
      items: [],
      totalCount: 0,
      totalUnreadCount: 0,
      hasMore: false,
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

  @override
  Future<void> markItemReadAt(
    ServerScopeId serverId, {
    required String channelId,
    required int seq,
  }) async {}
}
