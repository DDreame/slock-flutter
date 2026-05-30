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

// ---------------------------------------------------------------------------
// #520: Home Lazy Loading — Phase A (test-only)
//
// 1 test for lazy build invariant:
//   INV-HOME-LAZY-1: Off-screen sections not built until scrolled into view
//
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 1. Off-screen sections not built until scrolled (INV-HOME-LAZY-1)
  //
  // Phase B: Migrate the success ListView(children: [...]) to
  //   CustomScrollView + SliverList or ListView.builder so sections
  //   are built lazily (only when scrolled into the viewport).
  // -----------------------------------------------------------------------
  testWidgets(
    'Home: off-screen sections not built until scrolled into view '
    '(INV-HOME-LAZY-1)',
    skip: false,
    (tester) async {
      // Use a small viewport to guarantee the agents section starts
      // off-screen (tasks + unread fill the visible area).
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildApp(
          router: _buildRouter(),
          homeRepository: const _FakeHomeRepository(_snapshotWithTasks),
          tasksRepository: _FakeTasksRepository(tasks: _manyTasks),
        ),
      );
      await tester.pumpAndSettle();

      // Tasks section must be visible (it's the first section).
      expect(
        find.byKey(const ValueKey('home-card-tasks')),
        findsOneWidget,
        reason: 'Tasks section must be built (on-screen)',
      );

      // Agents section must NOT be built yet — it's below the fold.
      expect(
        find.byKey(const ValueKey('home-card-agents')),
        findsNothing,
        reason: 'Agents section must not be built while off-screen '
            '(INV-HOME-LAZY-1)',
      );

      // Scroll down to bring agents into view.
      await tester.drag(
        find.byKey(const ValueKey('home-card-tasks')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      // Now agents section must be built.
      expect(
        find.byKey(const ValueKey('home-card-agents')),
        findsOneWidget,
        reason: 'Agents section must be built after scrolling into view '
            '(INV-HOME-LAZY-1)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

/// Snapshot with enough channels for task resolution.
const _snapshotWithTasks = HomeWorkspaceSnapshot(
  serverId: ServerScopeId('server-1'),
  channels: [
    HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
      name: 'general',
    ),
  ],
  directMessages: [],
);

/// Many tasks to make the tasks section tall enough to push agents off-screen.
final _manyTasks = List.generate(
  5,
  (i) => TaskItem(
    id: 'task-$i',
    channelId: 'general',
    channelType: 'channel',
    messageId: 'msg-$i',
    taskNumber: i + 1,
    title: 'Task number $i with enough text to fill a row',
    status: 'in_progress',
    createdById: 'user-1',
    createdByName: 'Tester',
    createdByType: 'human',
    createdAt: DateTime.utc(2026, 5, 16, 10, i),
  ),
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
        const _FakeInboxRepository(),
      ),
      homeMachineCountLoaderProvider.overrideWithValue(
        (_) async => 0,
      ),
      agentsMachinesLoaderProvider.overrideWithValue(
        () async => const [],
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
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('agents:${state.pathParameters['serverId']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/tasks',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('tasks:${state.pathParameters['serverId']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/unread',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('unread:${state.pathParameters['serverId']}'),
          ),
        ),
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

class _FakeServerListRepository implements ServerListRepository {
  const _FakeServerListRepository();

  @override
  Future<List<ServerSummary>> loadServers() async => const [];
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(
    ServerScopeId serverId,
  ) async {
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
  const _FakeTasksRepository({this.tasks = const []});

  final List<TaskItem> tasks;

  @override
  Future<List<TaskItem>> listServerTasks(
    ServerScopeId serverId,
  ) async {
    return tasks;
  }

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

  @override
  Future<TaskItem> getTaskByNumber(
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeThreadRepository implements ThreadRepository {
  const _FakeThreadRepository();

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async {
    return const [];
  }

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

class _FakeInboxRepository implements InboxRepository {
  const _FakeInboxRepository();

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
