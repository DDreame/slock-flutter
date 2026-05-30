// ignore_for_file: lines_longer_than_80_chars, deprecated_member_use
import 'dart:ui';

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
import 'package:slock_app/l10n/app_localizations_provider.dart';

// ---------------------------------------------------------------------------
// #561 Phase A — Home Page Accessibility Gaps
//
// INV-A11Y-1: "View all" GestureDetector wrapped in Semantics(button: true)
// INV-A11Y-2: UnreadItemRow has accessible label with channel + preview
//
// Phase A — all tests skip: true.
// ---------------------------------------------------------------------------

void main() {
  group('Home page accessibility', () {
    testWidgets(
      '"View all" wrapped in Semantics(button: true) (INV-A11Y-1)',
      skip: true,
      (tester) async {
        // Setup: Render the real HomePage with at least 1 task so the
        // tasks card renders the "View all" affordance.
        // The "View all →" GestureDetector in _SummaryCardBase must
        // be wrapped in Semantics(button: true) so assistive technologies
        // announce it as an interactive button.
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_snapshotWithTasks),
            tasksRepository: _FakeTasksRepository(tasks: _sampleTasks),
          ),
        );
        await tester.pumpAndSettle();

        // Phase B assertion: find a Semantics node with button=true
        // that encloses the "View all →" text.
        final viewAllFinder = find.byKey(
          const ValueKey('card-view-all-tasks'),
        );
        expect(viewAllFinder, findsOneWidget,
            reason: 'Tasks card must show "View all" link');

        // The "View all" affordance must have button semantics.
        final semantics = tester.getSemantics(viewAllFinder);
        expect(
          semantics.getSemanticsData().hasFlag(SemanticsFlag.isButton),
          isTrue,
          reason: '"View all" must have button semantics (INV-A11Y-1)',
        );
      },
    );

    testWidgets(
      'UnreadItemRow has accessible label with channel + preview (INV-A11Y-2)',
      skip: true,
      (tester) async {
        // Setup: Render the real HomePage with unread items from
        // InboxRepository so the unread section renders _UnreadItemRow.
        // Each row's GestureDetector must have Semantics with a merged
        // label containing the channel name and preview text.
        final router = _buildRouter();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            homeRepository: const _FakeHomeRepository(_defaultSnapshot),
            inboxRepository: const _FakeInboxRepository(items: [
              InboxItem(
                channelId: 'general',
                kind: InboxItemKind.channel,
                unreadCount: 3,
                channelName: 'general',
                preview: 'Hello world',
              ),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        // Phase B assertion: the unread item row must have
        // semantics containing both channel name and preview.
        final unreadRow = find.byKey(const ValueKey('unread-item-0'));
        expect(unreadRow, findsOneWidget,
            reason: 'Unread item row must be rendered');

        final semantics = tester.getSemantics(unreadRow);
        expect(
          semantics.label,
          allOf(contains('general'), contains('Hello world')),
          reason: 'UnreadItemRow must have accessible label (INV-A11Y-2)',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _serverId = ServerScopeId('server-1');

const _defaultSnapshot = HomeWorkspaceSnapshot(
  serverId: _serverId,
  channels: [
    HomeChannelSummary(
      scopeId: ChannelScopeId(serverId: _serverId, value: 'general'),
      name: 'general',
    ),
  ],
  directMessages: [],
);

const _snapshotWithTasks = HomeWorkspaceSnapshot(
  serverId: _serverId,
  channels: [
    HomeChannelSummary(
      scopeId: ChannelScopeId(serverId: _serverId, value: 'general'),
      name: 'general',
    ),
  ],
  directMessages: [],
);

final _sampleTasks = [
  TaskItem(
    id: 'task-1',
    taskNumber: 1,
    title: 'Fix the login bug',
    status: 'todo',
    channelId: 'general',
    channelType: 'channel',
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime.parse('2026-05-18T00:00:00Z'),
  ),
  TaskItem(
    id: 'task-2',
    taskNumber: 2,
    title: 'Add dark mode',
    status: 'in_progress',
    channelId: 'general',
    channelType: 'channel',
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime.parse('2026-05-18T00:00:00Z'),
  ),
  TaskItem(
    id: 'task-3',
    taskNumber: 3,
    title: 'Update docs',
    status: 'todo',
    channelId: 'general',
    channelType: 'channel',
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime.parse('2026-05-18T00:00:00Z'),
  ),
  TaskItem(
    id: 'task-4',
    taskNumber: 4,
    title: 'Review PR',
    status: 'todo',
    channelId: 'general',
    channelType: 'channel',
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime.parse('2026-05-18T00:00:00Z'),
  ),
  TaskItem(
    id: 'task-5',
    taskNumber: 5,
    title: 'Deploy v2',
    status: 'todo',
    channelId: 'general',
    channelType: 'channel',
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime.parse('2026-05-18T00:00:00Z'),
  ),
  TaskItem(
    id: 'task-6',
    taskNumber: 6,
    title: 'Extra task for overflow',
    status: 'todo',
    channelId: 'general',
    channelType: 'channel',
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime.parse('2026-05-18T00:00:00Z'),
  ),
];

Widget _buildApp({
  required GoRouter router,
  required HomeRepository homeRepository,
  TasksRepository tasksRepository = const _FakeTasksRepository(),
  InboxRepository inboxRepository = const _FakeInboxRepository(),
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
      inboxRepositoryProvider.overrideWithValue(inboxRepository),
      homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
      agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      homeNowProvider.overrideWith(
        (ref) => Stream.value(DateTime.parse('2026-05-18T00:00:00Z')),
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
  ) async =>
      null;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async =>
      snapshot;

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
  const _FakeInboxRepository({this.items = const []});

  final List<InboxItem> items;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async =>
      InboxResponse(
        items: items,
        totalCount: items.length,
        totalUnreadCount: items.length,
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

  @override
  Future<void> markItemReadAt(
    ServerScopeId serverId, {
    required String channelId,
    required int seq,
  }) async {}
}
