import 'dart:async';

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

// ---------------------------------------------------------------------------
// #510: Projection SWR filter-switch 盲区修复 — Phase A (test-only)
//
// Test for filter-switch loading state in UnreadListPage.
//
// BUG 2 mechanism:
//   UnreadListPage watches unreadSourceProjectionProvider which returns
//   empty state when inboxState.status != success (provider guard).
//   During filter switch: status=loading → projection empty →
//   items.isEmpty && hiddenItems.isEmpty → _buildBody shows full-screen
//   CircularProgressIndicator instead of skeleton or stale data.
//
// Test 3 skip: true until Phase B fixes UnreadListPage to show skeleton
// (not spinner) during filter-switch loading.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 3. UnreadListPage: filter switch must NOT show full-screen spinner
  //
  // Phase B: UnreadListPage._buildBody must show skeleton (or stale data)
  //          during filter-switch loading — not a spinner that gives
  //          no indication of content.
  // -----------------------------------------------------------------------
  testWidgets(
    'UnreadListPage: filter switch does not show full-screen spinner',
    (tester) async {
      final repo = _ControllableInboxRepository();

      // Initial load: 2 unread channels (filter=all by default).
      // Queue twice — auto-load microtask fires first, then UI may trigger.
      repo.queueResponse(const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            channelName: 'general',
            unreadCount: 2,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-2',
            channelName: 'random',
            unreadCount: 1,
          ),
        ],
        totalCount: 2,
        totalUnreadCount: 3,
        hasMore: false,
      ));
      repo.queueResponse(const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            channelName: 'general',
            unreadCount: 2,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-2',
            channelName: 'random',
            unreadCount: 1,
          ),
        ],
        totalCount: 2,
        totalUnreadCount: 3,
        hasMore: false,
      ));

      // Home snapshot with matching channels for visibility resolution.
      const snapshot = HomeWorkspaceSnapshot(
        serverId: ServerScopeId('server-1'),
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-1',
            ),
            name: 'general',
          ),
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-2',
            ),
            name: 'random',
          ),
        ],
        directMessages: [],
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
            inboxRepositoryProvider.overrideWithValue(repo),
            homeRepositoryProvider.overrideWithValue(
              const _FakeHomeRepository(snapshot),
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

      // Verify initial load succeeded — list visible with items.
      expect(
        find.byKey(const ValueKey('unread-list-view')),
        findsOneWidget,
        reason: 'UnreadListPage must show list after initial load',
      );

      // Block the next fetch (filter-switch load).
      final completer = repo.blockNextFetch();

      // Tap filter toggle to switch from All → Unread.
      await tester.tap(find.byKey(const ValueKey('unread-filter-toggle')));
      await tester.pump(); // Process filter-switch state change.

      // No full-screen spinner during filter switch.
      // Currently FAILS: unreadSourceProjectionProvider returns empty
      // (guard: status != success) → items.isEmpty && hiddenItems.isEmpty
      // → _buildBody renders CircularProgressIndicator.
      expect(
        find.byKey(const ValueKey('unread-list-loading')),
        findsNothing,
        reason: 'Filter switch must NOT show full-screen spinner '
            '(should show skeleton or stale data — BUG 2)',
      );

      // Complete the request so test cleanup works.
      completer.complete(const InboxResponse(
        items: [],
        totalCount: 0,
        totalUnreadCount: 0,
        hasMore: false,
      ));
      await tester.pumpAndSettle();
    },
  );
}

// ---------------------------------------------------------------------------
// Controllable inbox repository — same pattern as inbox_filter_switch_test.
// ---------------------------------------------------------------------------

class _ControllableInboxRepository implements InboxRepository {
  final List<InboxResponse> _responses = [];
  Completer<InboxResponse>? _blockingCompleter;
  int _fetchCount = 0;

  void queueResponse(InboxResponse response) {
    _responses.add(response);
  }

  Completer<InboxResponse> blockNextFetch() {
    _blockingCompleter = Completer<InboxResponse>();
    return _blockingCompleter!;
  }

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    final index = _fetchCount++;
    if (index < _responses.length) {
      return _responses[index];
    }
    if (_blockingCompleter != null && !_blockingCompleter!.isCompleted) {
      return _blockingCompleter!.future;
    }
    return const InboxResponse(
      items: [],
      totalCount: 0,
      totalUnreadCount: 0,
      hasMore: false,
    );
  }

  @override
  Future<void> markItemRead(ServerScopeId serverId,
      {required String channelId}) async {}

  @override
  Future<void> markItemDone(ServerScopeId serverId,
      {required String channelId}) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

// ---------------------------------------------------------------------------
// Fakes (same as unread_list_page_test.dart)
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
