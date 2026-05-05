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
import 'package:slock_app/features/home/presentation/page/unread_list_page.dart';
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

void main() {
  group('UnreadListPage', () {
    testWidgets(
      'shows all items without 5-item cap',
      (tester) async {
        // Create 8 thread inbox items with unread > 0
        final items = List.generate(
          8,
          (i) => InboxItem(
            kind: InboxItemKind.thread,
            channelId: 'ulp-msg-$i',
            threadChannelId: 'ulp-msg-$i',
            parentChannelId: 'general',
            parentMessageId: 'ulp-msg-$i',
            channelName: 'general',
            threadTitle: 'Thread $i',
            unreadCount: 1,
          ),
        );

        final router = GoRouter(
          initialLocation: '/servers/server-1/unread',
          routes: [
            GoRoute(
              path: '/servers/:serverId/unread',
              builder: (context, state) => UnreadListPage(
                serverId: state.pathParameters['serverId']!,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerScopeIdProvider.overrideWithValue(
                const ServerScopeId('server-1'),
              ),
              inboxRepositoryProvider.overrideWithValue(
                _ConfigurableInboxRepository(items: items),
              ),
              homeRepositoryProvider.overrideWithValue(
                const _FakeHomeRepository(_snapshot),
              ),
              serverListRepositoryProvider.overrideWithValue(
                const _FakeServerListRepository([]),
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
              homeMachineCountLoaderProvider.overrideWithValue(
                (_) async => 0,
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // All 8 items should be visible (no 5-item cap)
        expect(
          find.byKey(const ValueKey('unread-list-view')),
          findsOneWidget,
          reason: 'UnreadListPage should show the list view',
        );

        for (var i = 0; i < 8; i++) {
          expect(
            find.byKey(
              ValueKey('unread-list-item-thread:ulp-msg-$i'),
            ),
            findsOneWidget,
            reason: 'Item $i should be visible '
                '(no 5-item cap on full list page)',
          );
        }
      },
    );

    testWidgets(
      'shows empty state when no unreads',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/servers/server-1/unread',
          routes: [
            GoRoute(
              path: '/servers/:serverId/unread',
              builder: (context, state) => UnreadListPage(
                serverId: state.pathParameters['serverId']!,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerScopeIdProvider.overrideWithValue(
                const ServerScopeId('server-1'),
              ),
              inboxRepositoryProvider.overrideWithValue(
                const _EmptyInboxRepository(),
              ),
              homeRepositoryProvider.overrideWithValue(
                const _FakeHomeRepository(_snapshot),
              ),
              serverListRepositoryProvider.overrideWithValue(
                const _FakeServerListRepository([]),
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
              homeMachineCountLoaderProvider.overrideWithValue(
                (_) async => 0,
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('unread-list-empty')),
          findsOneWidget,
          reason: 'Should show empty state when no unreads',
        );
        expect(find.text('All caught up'), findsOneWidget);
      },
    );

    testWidgets(
      'uses inbox adapter with source labels',
      (tester) async {
        final items = [
          const InboxItem(
            kind: InboxItemKind.thread,
            channelId: 'agg-msg',
            threadChannelId: 'agg-msg',
            parentChannelId: 'general',
            parentMessageId: 'agg-msg',
            channelName: 'general',
            threadTitle: 'Thread topic',
            unreadCount: 3,
          ),
        ];

        final router = GoRouter(
          initialLocation: '/servers/server-1/unread',
          routes: [
            GoRoute(
              path: '/servers/:serverId/unread',
              builder: (context, state) => UnreadListPage(
                serverId: state.pathParameters['serverId']!,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerScopeIdProvider.overrideWithValue(
                const ServerScopeId('server-1'),
              ),
              inboxRepositoryProvider.overrideWithValue(
                _ConfigurableInboxRepository(items: items),
              ),
              homeRepositoryProvider.overrideWithValue(
                const _FakeHomeRepository(_snapshot),
              ),
              serverListRepositoryProvider.overrideWithValue(
                const _FakeServerListRepository([]),
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
              homeMachineCountLoaderProvider.overrideWithValue(
                (_) async => 0,
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Thread source label should include parent channel name
        expect(
          find.text('#general \u00b7 Thread topic'),
          findsOneWidget,
          reason: 'UnreadListPage should show source labels '
              'from inbox adapter',
        );
      },
    );
  });
}

// -------------------------------------------------------------------------
// Test data
// -------------------------------------------------------------------------

const _snapshot = HomeWorkspaceSnapshot(
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

// -------------------------------------------------------------------------
// Fakes
// -------------------------------------------------------------------------

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
}

class _ConfigurableInboxRepository implements InboxRepository {
  const _ConfigurableInboxRepository({this.items = const []});

  final List<InboxItem> items;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    final totalUnread = items.fold<int>(0, (s, i) => s + i.unreadCount);
    return InboxResponse(
      items: items,
      totalCount: items.length,
      totalUnreadCount: totalUnread,
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
}

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
  const _FakeServerListRepository(this.servers);

  final List<ServerSummary> servers;

  @override
  Future<List<ServerSummary>> loadServers() async => servers;
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
