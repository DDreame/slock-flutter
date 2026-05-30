// =============================================================================
// #854 — _UnreadItemRow Semantics (button:true) + Diagnostics Filter Chips
//        Overflow
//
// Load-bearing tests:
// 1. _UnreadItemRow: Semantics(button: true) ensures assistive technologies
//    announce the row as a button.
//    (Removing button:true → hasFlag(isButton) check fails)
// 2. Diagnostics filter chips: SingleChildScrollView prevents overflow on
//    narrow screens with verbose locales.
//    (Removing scroll wrapper → layout overflow assertion fires)
// =============================================================================

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
import 'package:slock_app/features/settings/presentation/page/diagnostics_page.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ===========================================================================
  // Group 1: _UnreadItemRow Semantics — button:true + container:true
  // ===========================================================================
  group('#854 — _UnreadItemRow Semantics button flag', () {
    testWidgets('UnreadItemRow has isButton semantics flag', (tester) async {
      final router = _buildRouter();

      await tester.pumpWidget(
        _buildHomeApp(
          router: router,
          inboxItems: const [
            InboxItem(
              channelId: 'general',
              kind: InboxItemKind.channel,
              unreadCount: 3,
              channelName: 'general',
              preview: 'Hello world',
              senderName: 'Alice',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Find the unread item row by key pattern.
      final rowFinder = find.byKey(const ValueKey('unread-item-0'));
      expect(rowFinder, findsOneWidget,
          reason: 'Unread item row must render when inbox has items');

      // Verify the Semantics node has isButton flag.
      final semantics = tester.getSemantics(rowFinder);
      expect(
        semantics.getSemanticsData().hasFlag(SemanticsFlag.isButton),
        isTrue,
        reason: 'Removing Semantics(button: true) from _UnreadItemRow → '
            'isButton flag disappears (INV-854-1).',
      );
    });

    testWidgets('UnreadItemRow semantics label includes title and preview',
        (tester) async {
      final router = _buildRouter();

      await tester.pumpWidget(
        _buildHomeApp(
          router: router,
          inboxItems: const [
            InboxItem(
              channelId: 'general',
              kind: InboxItemKind.channel,
              unreadCount: 1,
              channelName: 'general',
              preview: 'Code review done',
              senderName: 'Alice',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final rowFinder = find.byKey(const ValueKey('unread-item-0'));
      expect(rowFinder, findsOneWidget);

      final semantics = tester.getSemantics(rowFinder);
      final label = semantics.label;
      expect(label, contains('general'),
          reason: 'Semantics label must include title');
      expect(label, contains('Code review done'),
          reason: 'Semantics label must include preview text');
    });
  });

  // ===========================================================================
  // Group 2: Diagnostics filter chips — no overflow on narrow screens
  // ===========================================================================
  group('#854 — Diagnostics filter chips overflow', () {
    testWidgets('filter chips do not overflow at 200px width', (tester) async {
      final collector = DiagnosticsCollector();
      collector.info('test', 'Sample entry');

      await tester.pumpWidget(
        _buildDiagnosticsApp(
          collector: collector,
          locale: const Locale('zh'),
          width: 200,
        ),
      );
      await tester.pumpAndSettle();

      // If SingleChildScrollView is missing, Flutter would report an
      // overflow error. We verify no overflow by checking that the widget
      // tree renders without error and the scroll view exists.
      final scrollFinder = find.byKey(
        const ValueKey('diagnostics-filter-scroll'),
      );
      expect(scrollFinder, findsOneWidget,
          reason: 'Removing SingleChildScrollView → no scroll key found, '
              'and overflow error fires (INV-854-2).');
    });

    testWidgets('filter chips render all 4 chips in scroll view',
        (tester) async {
      final collector = DiagnosticsCollector();

      await tester.pumpWidget(
        _buildDiagnosticsApp(
          collector: collector,
          locale: const Locale('es'),
          width: 250,
        ),
      );
      await tester.pumpAndSettle();

      // All 4 filter chips should be present in the widget tree.
      expect(
        find.byKey(const ValueKey('diagnostics-filter-all')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('diagnostics-filter-info')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('diagnostics-filter-warning')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('diagnostics-filter-error')),
        findsOneWidget,
      );
    });
  });
}

// =============================================================================
// Helper builders
// =============================================================================

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

Widget _buildHomeApp({
  required GoRouter router,
  List<InboxItem> inboxItems = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      activeServerScopeIdProvider.overrideWithValue(_serverId),
      homeRepositoryProvider.overrideWithValue(
        const _FakeHomeRepository(_defaultSnapshot),
      ),
      serverListRepositoryProvider.overrideWithValue(
        const _FakeServerListRepository(),
      ),
      sidebarOrderRepositoryProvider.overrideWithValue(
        const _FakeSidebarOrderRepository(),
      ),
      agentsRepositoryProvider.overrideWithValue(const _FakeAgentsRepository()),
      tasksRepositoryProvider.overrideWithValue(const _FakeTasksRepository()),
      threadRepositoryProvider.overrideWithValue(const _FakeThreadRepository()),
      inboxRepositoryProvider
          .overrideWithValue(_FakeInboxRepository(items: inboxItems)),
      homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
      agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      homeNowProvider.overrideWith(
        (ref) => Stream.value(DateTime.parse('2026-05-18T00:00:00Z')),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Widget _buildDiagnosticsApp({
  required DiagnosticsCollector collector,
  Locale locale = const Locale('en'),
  double width = 400,
}) {
  return ProviderScope(
    overrides: [
      diagnosticsCollectorProvider.overrideWithValue(collector),
      backgroundWorkerDiagnosticsProvider.overrideWith(
        (ref) async => null,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SizedBox(
        width: width,
        child: const MediaQuery(
          data: MediaQueryData(size: Size(200, 800)),
          child: DiagnosticsPage(),
        ),
      ),
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
        path: '/servers/:serverId/channels/:channelId',
        builder: (context, state) => const Scaffold(body: Placeholder()),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:dmId',
        builder: (context, state) => const Scaffold(body: Placeholder()),
      ),
      GoRoute(
        path: '/servers/:serverId/tasks',
        builder: (context, state) => const Scaffold(body: Placeholder()),
      ),
    ],
  );
}

// =============================================================================
// Fakes
// =============================================================================

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
