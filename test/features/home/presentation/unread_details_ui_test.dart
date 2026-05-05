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
import 'package:slock_app/features/home/application/home_unread_item.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/inbox/application/inbox_to_home_unread_adapter.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';

/// TDD tests for Z2 three-line unread UI spec:
/// - Type pill per kind (THREAD/CHANNEL/DM) with correct color
/// - Source label on line 1
/// - Destination title bold on line 2
/// - "senderName: preview" on line 3
/// - Missing sender graceful display
/// - Mark all read removed from home unread section
/// - Header "View all →" links to inbox
void main() {
  group('HomeUnreadItem model', () {
    test('senderName field is available and nullable', () {
      const item = HomeUnreadItem(
        kind: HomeUnreadKind.channel,
        id: 'channel:general',
        title: 'general',
        unreadCount: 3,
        senderName: 'Alice',
        preview: 'Hello world',
      );
      expect(item.senderName, 'Alice');
      expect(item.preview, 'Hello world');
    });

    test('senderName can be null', () {
      const item = HomeUnreadItem(
        kind: HomeUnreadKind.channel,
        id: 'channel:general',
        title: 'general',
        unreadCount: 1,
      );
      expect(item.senderName, isNull);
    });
  });

  group('inboxItemToHomeUnreadItem adapter', () {
    test('maps senderName from InboxItem', () {
      const item = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'general',
        channelName: 'general',
        senderName: 'Bob',
        preview: 'Hey everyone',
        unreadCount: 2,
      );

      final result = inboxItemToHomeUnreadItem(
        item,
        serverId: const ServerScopeId('server-1'),
      );

      expect(result.senderName, 'Bob');
      expect(result.preview, 'Hey everyone');
    });

    test('maps null senderName when absent', () {
      const item = InboxItem(
        kind: InboxItemKind.dm,
        channelId: 'dm-1',
        channelName: 'Dave',
        unreadCount: 1,
      );

      final result = inboxItemToHomeUnreadItem(
        item,
        serverId: const ServerScopeId('server-1'),
      );

      expect(result.senderName, isNull);
    });

    test('thread kind maps senderName and sourceLabel', () {
      const item = InboxItem(
        kind: InboxItemKind.thread,
        channelId: 'thread-1',
        threadChannelId: 'thread-1',
        parentChannelId: 'general',
        parentMessageId: 'msg-1',
        channelName: 'general',
        threadTitle: 'Design review',
        senderName: 'Carol',
        preview: 'LGTM',
        unreadCount: 5,
      );

      final result = inboxItemToHomeUnreadItem(
        item,
        serverId: const ServerScopeId('server-1'),
      );

      expect(result.senderName, 'Carol');
      expect(result.kind, HomeUnreadKind.thread);
      expect(result.sourceLabel, contains('#general'));
      expect(result.title, 'Design review');
    });
  });

  group('Z2 three-line unread UI rendering', () {
    testWidgets('thread item renders type pill with THREAD label',
        (tester) async {
      await _pumpHomeWithInboxItems(
        tester,
        items: const [
          InboxItem(
            kind: InboxItemKind.thread,
            channelId: 'th-1',
            threadChannelId: 'th-1',
            parentChannelId: 'general',
            parentMessageId: 'msg-1',
            channelName: 'general',
            threadTitle: 'Design review',
            senderName: 'Alice',
            preview: 'Looks good',
            unreadCount: 2,
          ),
        ],
      );

      expect(
        find.byKey(const ValueKey('unread-pill-thread:th-1')),
        findsOneWidget,
        reason: 'Thread item should have a type pill',
      );
      expect(
        find.text('THREAD'),
        findsOneWidget,
        reason: 'Thread type pill should say THREAD',
      );
    });

    testWidgets('channel item renders type pill with CHANNEL label',
        (tester) async {
      await _pumpHomeWithInboxItems(
        tester,
        items: const [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'general',
            channelName: 'general',
            senderName: 'Bob',
            preview: 'New message',
            unreadCount: 3,
          ),
        ],
      );

      expect(
        find.text('CHANNEL'),
        findsOneWidget,
        reason: 'Channel type pill should say CHANNEL',
      );
    });

    testWidgets('DM item renders type pill with DM label', (tester) async {
      await _pumpHomeWithInboxItems(
        tester,
        items: const [
          InboxItem(
            kind: InboxItemKind.dm,
            channelId: 'dm-1',
            channelName: 'Dave',
            senderName: 'Dave',
            preview: 'Hey!',
            unreadCount: 1,
          ),
        ],
      );

      expect(
        find.text('DM'),
        findsOneWidget,
        reason: 'DM type pill should say DM',
      );
    });

    testWidgets('renders destination title on line 2', (tester) async {
      await _pumpHomeWithInboxItems(
        tester,
        items: const [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'announcements',
            channelName: 'announcements',
            senderName: 'Admin',
            preview: 'Important update',
            unreadCount: 1,
          ),
        ],
      );

      expect(
        find.byKey(const ValueKey('unread-title-channel:announcements')),
        findsOneWidget,
        reason: 'Destination title should be rendered',
      );
    });

    testWidgets('renders senderName: preview on line 3', (tester) async {
      await _pumpHomeWithInboxItems(
        tester,
        items: const [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'general',
            channelName: 'general',
            senderName: 'Carol',
            preview: 'Hello world',
            unreadCount: 2,
          ),
        ],
      );

      expect(
        find.text('Carol: Hello world'),
        findsOneWidget,
        reason: 'Line 3 should show "senderName: preview"',
      );
    });

    testWidgets('missing sender shows just preview gracefully', (tester) async {
      await _pumpHomeWithInboxItems(
        tester,
        items: const [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'random',
            channelName: 'random',
            preview: 'Some message without sender',
            unreadCount: 1,
          ),
        ],
      );

      expect(
        find.text('Some message without sender'),
        findsOneWidget,
        reason: 'Missing sender should show just the preview text',
      );
      expect(
        find.textContaining('null:'),
        findsNothing,
        reason: 'Should not show "null:" when sender is missing',
      );
    });

    testWidgets('missing preview and sender shows no line 3', (tester) async {
      await _pumpHomeWithInboxItems(
        tester,
        items: const [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'empty',
            channelName: 'empty',
            unreadCount: 1,
          ),
        ],
      );

      expect(
        find.byKey(const ValueKey('unread-preview-channel:empty')),
        findsNothing,
        reason: 'No line 3 when both sender and preview are missing',
      );
    });

    testWidgets('mark all read button is NOT present in home unread section',
        (tester) async {
      await _pumpHomeWithInboxItems(
        tester,
        items: const [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'general',
            channelName: 'general',
            unreadCount: 5,
          ),
        ],
      );

      expect(
        find.byKey(const ValueKey('home-unread-mark-all')),
        findsNothing,
        reason: 'Mark all read should be removed from home unread section',
      );
    });

    testWidgets('source label is displayed on line 1', (tester) async {
      await _pumpHomeWithInboxItems(
        tester,
        items: const [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'general',
            channelName: 'general',
            senderName: 'Eve',
            preview: 'Hi',
            unreadCount: 1,
          ),
        ],
      );

      expect(
        find.byKey(const ValueKey('unread-source-channel:general')),
        findsOneWidget,
        reason: 'Source label should be displayed on line 1',
      );
    });

    testWidgets('left icon shows correct glyph per kind', (tester) async {
      await _pumpHomeWithInboxItems(
        tester,
        items: const [
          InboxItem(
            kind: InboxItemKind.thread,
            channelId: 'th-glyph',
            threadChannelId: 'th-glyph',
            parentChannelId: 'general',
            parentMessageId: 'msg-g',
            channelName: 'general',
            threadTitle: 'Test',
            unreadCount: 1,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-glyph',
            channelName: 'channel-x',
            unreadCount: 1,
          ),
          InboxItem(
            kind: InboxItemKind.dm,
            channelId: 'dm-glyph',
            channelName: 'Frank',
            unreadCount: 1,
          ),
        ],
      );

      expect(
        find.byKey(const ValueKey('unread-kind-thread')),
        findsOneWidget,
        reason: 'Thread glyph badge should be present',
      );
      expect(
        find.byKey(const ValueKey('unread-kind-channel')),
        findsOneWidget,
        reason: 'Channel glyph badge should be present',
      );
      expect(
        find.byKey(const ValueKey('unread-kind-directMessage')),
        findsOneWidget,
        reason: 'DM glyph badge should be present',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Test infrastructure
// ---------------------------------------------------------------------------

const _unreadSnapshot = HomeWorkspaceSnapshot(
  serverId: ServerScopeId('server-1'),
  channels: [],
  directMessages: [],
);

GoRouter _buildRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/servers/:sid/unread',
        builder: (context, state) => const Scaffold(body: Text('Unread')),
      ),
      GoRoute(
        path: '/servers/:sid/channels/:cid',
        builder: (context, state) => const Scaffold(body: Text('Channel')),
      ),
      GoRoute(
        path: '/servers/:sid/dms/:did',
        builder: (context, state) => const Scaffold(body: Text('DM')),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Scaffold(body: Text('Settings')),
      ),
    ],
  );
}

Future<void> _pumpHomeWithInboxItems(
  WidgetTester tester, {
  required List<InboxItem> items,
}) async {
  final router = _buildRouter();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
        homeRepositoryProvider.overrideWithValue(
          const _FakeHomeRepository(_unreadSnapshot),
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
        inboxRepositoryProvider.overrideWithValue(
          _ConfigurableInboxRepository(items: items),
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
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this.snapshot);
  final HomeWorkspaceSnapshot snapshot;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
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
  Future<List<AgentItem>> listAgents() async => [];

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
  const _FakeTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async => [];

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
