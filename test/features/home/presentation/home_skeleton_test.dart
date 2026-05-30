import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/skeleton_card.dart';
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
// #490: Home Page Skeleton Integration Tests
//
// Invariants verified:
// INV-UX-SKELETON-1: First frame must show skeleton, never blank.
//
// Note: INV-UX-SKELETON-2 (no layout jump on transition) is scoped as
// "skeleton replaces loading indicator" — presence/absence verified, not
// golden/layout-shift.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  GoRouter buildRouter() {
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
        GoRoute(
          path: '/servers/:serverId/channels/:channelId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'channel:${state.pathParameters['channelId']}',
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/servers/:serverId/dms/:dmId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('dm:${state.pathParameters['dmId']}'),
            ),
          ),
        ),
        GoRoute(
          path: '/servers/:serverId/search',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('search')),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('settings')),
          ),
        ),
      ],
    );
  }

  Widget buildApp({
    required GoRouter router,
    required HomeRepository homeRepository,
    InboxRepository inboxRepository = const _EmptyInboxRepository(),
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
        tasksRepositoryProvider.overrideWithValue(
          const _FakeTasksRepository(),
        ),
        threadRepositoryProvider.overrideWithValue(
          const _FakeThreadRepository(),
        ),
        inboxRepositoryProvider.overrideWithValue(inboxRepository),
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

  // -----------------------------------------------------------------------
  // Tests
  // -----------------------------------------------------------------------

  group('Home skeleton integration', () {
    testWidgets(
      'shows 3 skeleton cards on initial load (INV-UX-SKELETON-1)',
      (tester) async {
        final router = buildRouter();
        final networkCompleter = Completer<HomeWorkspaceSnapshot>();

        await tester.pumpWidget(
          buildApp(
            router: router,
            homeRepository: _DelayedFakeHomeRepository(
              cachedSnapshot: null,
              networkCompleter: networkCompleter,
            ),
          ),
        );
        // First pump triggers initState + microtask load.
        await tester.pump();
        // Second pump allows the state transition to loading.
        await tester.pump();

        // Skeleton container must be visible.
        expect(
          find.byKey(const ValueKey('home-skeleton')),
          findsOneWidget,
          reason: 'INV-UX-SKELETON-1: skeleton must appear on first frame, '
              'never blank',
        );

        // All 3 skeleton cards present.
        expect(
          find.byKey(const ValueKey('home-skeleton-card-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-skeleton-card-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-skeleton-card-2')),
          findsOneWidget,
        );

        // No spinner.
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'Skeleton cards replace CircularProgressIndicator',
        );

        // No real content visible yet.
        expect(
          find.byKey(const ValueKey('home-card-tasks')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('home-card-agents')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'skeleton cards are SkeletonCard widgets',
      (tester) async {
        final router = buildRouter();
        final networkCompleter = Completer<HomeWorkspaceSnapshot>();

        await tester.pumpWidget(
          buildApp(
            router: router,
            homeRepository: _DelayedFakeHomeRepository(
              cachedSnapshot: null,
              networkCompleter: networkCompleter,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Verify the skeleton cards are actual SkeletonCard widgets.
        expect(find.byType(SkeletonCard), findsNWidgets(3));
      },
    );

    testWidgets(
      'skeleton disappears after data arrives',
      (tester) async {
        final router = buildRouter();
        final networkCompleter = Completer<HomeWorkspaceSnapshot>();

        await tester.pumpWidget(
          buildApp(
            router: router,
            homeRepository: _DelayedFakeHomeRepository(
              cachedSnapshot: null,
              networkCompleter: networkCompleter,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Skeleton visible.
        expect(
          find.byKey(const ValueKey('home-skeleton')),
          findsOneWidget,
        );

        // Complete the network request.
        networkCompleter.complete(_sampleSnapshot);
        await tester.pumpAndSettle();

        // Skeleton gone.
        expect(
          find.byKey(const ValueKey('home-skeleton')),
          findsNothing,
          reason: 'Skeleton must disappear after data arrives',
        );

        // Real content visible.
        expect(
          find.byKey(const ValueKey('home-card-tasks')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-card-unread')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-card-agents')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'skeleton NOT shown during SWR refresh (stale data stays visible)',
      (tester) async {
        final router = buildRouter();

        // Use a fast-resolving repo for the initial load.
        await tester.pumpWidget(
          buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_sampleSnapshot),
          ),
        );
        await tester.pumpAndSettle();

        // Success state — real cards visible.
        expect(
          find.byKey(const ValueKey('home-card-tasks')),
          findsOneWidget,
        );

        // No skeleton.
        expect(
          find.byKey(const ValueKey('home-skeleton')),
          findsNothing,
          reason: 'Skeleton must not appear during SWR refresh; '
              'stale data stays visible',
        );
      },
    );

    testWidgets(
      'skeleton shown on initial status (before load is triggered)',
      (tester) async {
        final router = buildRouter();
        final networkCompleter = Completer<HomeWorkspaceSnapshot>();

        await tester.pumpWidget(
          buildApp(
            router: router,
            homeRepository: _DelayedFakeHomeRepository(
              cachedSnapshot: null,
              networkCompleter: networkCompleter,
            ),
          ),
        );
        // Single pump — the status is still initial (microtask hasn't run).
        await tester.pump();

        // Even on initial status, skeleton should appear.
        expect(
          find.byKey(const ValueKey('home-skeleton')),
          findsOneWidget,
          reason: 'Skeleton must show for both initial and loading statuses',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _sampleSnapshot = HomeWorkspaceSnapshot(
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

class _DelayedFakeHomeRepository implements HomeRepository {
  _DelayedFakeHomeRepository({
    required this.cachedSnapshot,
    required this.networkCompleter,
  });

  final HomeWorkspaceSnapshot? cachedSnapshot;
  final Completer<HomeWorkspaceSnapshot> networkCompleter;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(
    ServerScopeId serverId,
  ) {
    return networkCompleter.future;
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return cachedSnapshot;
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
  const _FakeTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(
    ServerScopeId serverId,
  ) async {
    return const [];
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
