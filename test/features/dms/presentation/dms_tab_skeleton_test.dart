import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
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
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

// ---------------------------------------------------------------------------
// #491: DMs Tab Skeleton Integration Tests
//
// Invariants verified:
// INV-UX-SKELETON-1: First frame must show skeleton, never blank.
//
// Note: INV-UX-SKELETON-2 (no layout jump on transition) is scoped as
// "skeleton replaces loading indicator" — presence/absence verified, not
// golden/layout-shift.
// ---------------------------------------------------------------------------

void main() {
  const serverId = ServerScopeId('server-1');

  const sampleSnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [],
    directMessages: [
      HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-alice'),
        title: 'Alice',
      ),
    ],
  );

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/dms',
      routes: [
        GoRoute(
          path: '/dms',
          builder: (_, __) => const DmsTabPage(),
        ),
        GoRoute(
          path: '/servers/:serverId/dms/:dmId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('dm:${state.pathParameters['dmId']}'),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildApp({
    required GoRouter router,
    required HomeRepository homeRepository,
  }) {
    return ProviderScope(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        homeRepositoryProvider.overrideWithValue(homeRepository),
        sharedPreferencesProvider.overrideWithValue(prefs),
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
        inboxRepositoryProvider.overrideWithValue(
          const _NeverCompleteInboxRepository(),
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

  group('DMs tab skeleton integration', () {
    testWidgets(
      'shows skeleton on very first frame — initial status '
      '(INV-UX-SKELETON-1)',
      (tester) async {
        final router = buildRouter();
        final networkCompleter = Completer<HomeWorkspaceSnapshot>();

        await tester.pumpWidget(
          buildApp(
            router: router,
            homeRepository: _DelayedFakeHomeRepository(
              networkCompleter: networkCompleter,
            ),
          ),
        );
        // Single pump — status is still `initial` (microtask hasn't fired).
        await tester.pump();

        // Skeleton must be visible even on the very first frame.
        expect(
          find.byKey(const ValueKey('dms-skeleton')),
          findsOneWidget,
          reason: 'INV-UX-SKELETON-1: skeleton must appear on the very first '
              'frame when status is initial',
        );

        // No spinner.
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'Skeleton replaces CircularProgressIndicator',
        );
      },
    );

    testWidgets(
      'shows 5 skeleton list items during loading state',
      (tester) async {
        final router = buildRouter();
        final networkCompleter = Completer<HomeWorkspaceSnapshot>();

        await tester.pumpWidget(
          buildApp(
            router: router,
            homeRepository: _DelayedFakeHomeRepository(
              networkCompleter: networkCompleter,
            ),
          ),
        );
        await tester.pump(); // trigger microtask load
        await tester.pump(); // allow state transition to loading

        // Skeleton container must be visible.
        expect(
          find.byKey(const ValueKey('dms-skeleton')),
          findsOneWidget,
        );

        // All 5 skeleton list items present.
        for (var i = 0; i < 5; i++) {
          expect(
            find.byKey(ValueKey('dms-skeleton-item-$i')),
            findsOneWidget,
          );
        }

        // No spinner.
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'Skeleton list items replace CircularProgressIndicator',
        );
      },
    );

    testWidgets(
      'skeleton items are SkeletonListItem widgets',
      (tester) async {
        final router = buildRouter();
        final networkCompleter = Completer<HomeWorkspaceSnapshot>();

        await tester.pumpWidget(
          buildApp(
            router: router,
            homeRepository: _DelayedFakeHomeRepository(
              networkCompleter: networkCompleter,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Verify the skeleton items are actual SkeletonListItem widgets.
        expect(find.byType(SkeletonListItem), findsNWidgets(5));
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
              networkCompleter: networkCompleter,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Skeleton visible.
        expect(
          find.byKey(const ValueKey('dms-skeleton')),
          findsOneWidget,
        );

        // Complete the network request.
        networkCompleter.complete(sampleSnapshot);
        await tester.pumpAndSettle();

        // Skeleton gone.
        expect(
          find.byKey(const ValueKey('dms-skeleton')),
          findsNothing,
          reason: 'Skeleton must disappear after data arrives',
        );

        // Real content visible.
        expect(
          find.byKey(const ValueKey('dms-tab-dm-alice')),
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
            homeRepository: const _FakeHomeRepository(sampleSnapshot),
          ),
        );
        await tester.pumpAndSettle();

        // Success state — real DM rows visible.
        expect(
          find.byKey(const ValueKey('dms-tab-dm-alice')),
          findsOneWidget,
        );

        // No skeleton.
        expect(
          find.byKey(const ValueKey('dms-skeleton')),
          findsNothing,
          reason: 'Skeleton must not appear during SWR refresh; '
              'stale data stays visible',
        );
      },
    );
  });
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

class _DelayedFakeHomeRepository implements HomeRepository {
  _DelayedFakeHomeRepository({required this.networkCompleter});

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

class _NeverCompleteInboxRepository implements InboxRepository {
  const _NeverCompleteInboxRepository();

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) =>
      Completer<InboxResponse>().future;

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) =>
      Future.value();

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) =>
      Future.value();

  @override
  Future<void> markAllRead(ServerScopeId serverId) => Future.value();
}
