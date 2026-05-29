// =============================================================================
// Benchmark App Entry Point
//
// Minimal app shell that renders the real UI widgets with fake data providers.
// Used by benchmark tests to measure rendering performance without requiring
// a live server or real authentication.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:slock_app/l10n/l10n.dart';

/// Server scope ID used in benchmarks.
const benchmarkServerId = ServerScopeId('benchmark-server');

/// Builds the benchmark app widget with all providers overridden to fake
/// implementations. Returns a [ProviderScope] wrapping [MaterialApp] with
/// the [HomePage] as the default route.
Widget buildBenchmarkApp({int inboxItemCount = 50}) {
  return ProviderScope(
    overrides: [
      activeServerScopeIdProvider.overrideWithValue(benchmarkServerId),
      homeRepositoryProvider.overrideWithValue(
        _BenchmarkHomeRepository(),
      ),
      serverListRepositoryProvider.overrideWithValue(
        const _BenchmarkServerListRepository(),
      ),
      sidebarOrderRepositoryProvider.overrideWithValue(
        const _BenchmarkSidebarOrderRepository(),
      ),
      agentsRepositoryProvider.overrideWithValue(
        const _BenchmarkAgentsRepository(),
      ),
      tasksRepositoryProvider.overrideWithValue(
        _BenchmarkTasksRepository(),
      ),
      threadRepositoryProvider.overrideWithValue(
        const _BenchmarkThreadRepository(),
      ),
      inboxRepositoryProvider.overrideWithValue(
        _BenchmarkInboxRepository(itemCount: inboxItemCount),
      ),
      homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
      agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      homeNowProvider.overrideWith(
        (ref) => Stream.value(DateTime.now()),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomePage(),
    ),
  );
}

// =============================================================================
// Fake repositories for benchmarks
// =============================================================================

class _BenchmarkHomeRepository implements HomeRepository {
  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: List.generate(
        20,
        (i) => HomeChannelSummary(
          scopeId: ChannelScopeId(serverId: serverId, value: 'channel-$i'),
          name: 'channel-$i',
        ),
      ),
      directMessages: List.generate(
        10,
        (i) => HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(
            serverId: serverId,
            value: 'dm-$i',
          ),
          title: 'User $i',
        ),
      ),
    );
  }

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

class _BenchmarkServerListRepository implements ServerListRepository {
  const _BenchmarkServerListRepository();

  @override
  Future<List<ServerSummary>> loadServers() async => const [];
}

class _BenchmarkSidebarOrderRepository implements SidebarOrderRepository {
  const _BenchmarkSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async =>
      const SidebarOrder();

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}

class _BenchmarkAgentsRepository implements AgentsRepository {
  const _BenchmarkAgentsRepository();

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

class _BenchmarkTasksRepository implements TasksRepository {
  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    return List.generate(
      15,
      (i) => TaskItem(
        id: 'task-$i',
        taskNumber: i + 1,
        title: 'Benchmark task ${i + 1} — sample work item',
        status: i < 5 ? 'todo' : (i < 10 ? 'in_progress' : 'done'),
        channelId: 'channel-0',
        channelType: 'channel',
        createdById: 'user-${i % 5}',
        createdByName: 'User ${i % 5}',
        createdByType: 'human',
        createdAt: DateTime.now().subtract(Duration(hours: i)),
      ),
    );
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

class _BenchmarkThreadRepository implements ThreadRepository {
  const _BenchmarkThreadRepository();

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
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}

class _BenchmarkInboxRepository implements InboxRepository {
  _BenchmarkInboxRepository({this.itemCount = 50});

  final int itemCount;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    final items = List.generate(
      itemCount,
      (i) => InboxItem(
        channelId: 'channel-${i % 20}',
        kind: i % 5 == 0
            ? InboxItemKind.dm
            : (i % 7 == 0 ? InboxItemKind.thread : InboxItemKind.channel),
        unreadCount: (i % 3) + 1,
        channelName: 'channel-${i % 20}',
        preview: 'Message preview text for item $i — '
            'this is a sample message that simulates real content.',
        senderName: 'User ${i % 10}',
        lastActivityAt: DateTime.now().subtract(Duration(minutes: i * 5)),
      ),
    );
    return InboxResponse(
      items: items.skip(offset).take(limit).toList(),
      totalCount: items.length,
      totalUnreadCount: items.length,
      hasMore: offset + limit < items.length,
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
