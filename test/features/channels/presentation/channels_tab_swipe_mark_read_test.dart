import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake InboxStore that returns a fixed state.
class _SeedableInboxStore extends InboxStore {
  _SeedableInboxStore(this._initial);
  final InboxState _initial;

  @override
  InboxState build() => _initial;
}

void main() {
  const serverId = ServerScopeId('server-1');

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const channelGeneral = HomeChannelSummary(
    scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
    name: 'general',
  );

  const channelRandom = HomeChannelSummary(
    scopeId: ChannelScopeId(serverId: serverId, value: 'random'),
    name: 'random',
  );

  const snapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [channelGeneral, channelRandom],
    directMessages: [],
  );

  /// InboxState that makes 'general' channel unread.
  InboxState inboxWithGeneralUnread(int count) => InboxState(
        status: InboxStatus.success,
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'general',
            channelName: 'general',
            preview: 'Hello',
            unreadCount: count,
          ),
        ],
      );

  Widget buildApp({
    required HomeRepository homeRepository,
    InboxState? inboxState,
    void Function(ChannelScopeId)? onMarkRead,
  }) {
    final router = GoRouter(
      initialLocation: '/channels',
      routes: [
        GoRoute(
          path: '/channels',
          builder: (_, __) => const ChannelsTabPage(),
        ),
        GoRoute(
          path: '/servers/:serverId/channels/:channelId',
          builder: (_, state) => Scaffold(
            body: Center(
              child: Text(
                'channel:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
              ),
            ),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        channelMutedIdsProvider.overrideWith((ref) => <String>{}),
        activeServerScopeIdProvider.overrideWithValue(serverId),
        homeRepositoryProvider.overrideWithValue(homeRepository),
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
        markChannelReadUseCaseProvider.overrideWithValue(
          (scopeId) => onMarkRead?.call(scopeId),
        ),
        if (inboxState != null)
          inboxStoreProvider.overrideWith(
            () => _SeedableInboxStore(inboxState),
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

  group('Channels tab swipe-to-mark-read', () {
    testWidgets('left swipe on unread channel triggers markRead', (
      tester,
    ) async {
      ChannelScopeId? markedReadScopeId;

      await tester.pumpWidget(buildApp(
        homeRepository: const _FakeHomeRepository(snapshot),
        inboxState: inboxWithGeneralUnread(3),
        onMarkRead: (scopeId) => markedReadScopeId = scopeId,
      ));
      await tester.pumpAndSettle();

      // Fling left to exceed dismiss threshold.
      await tester.fling(
        find.byKey(const ValueKey('channels-tab-general')),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(markedReadScopeId, channelGeneral.scopeId);
    });

    testWidgets('channel row stays visible after swipe', (tester) async {
      await tester.pumpWidget(buildApp(
        homeRepository: const _FakeHomeRepository(snapshot),
        inboxState: inboxWithGeneralUnread(5),
        onMarkRead: (_) {},
      ));
      await tester.pumpAndSettle();

      // Fling left.
      await tester.fling(
        find.byKey(const ValueKey('channels-tab-general')),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      // Row should still be visible (not dismissed).
      expect(
        find.byKey(const ValueKey('channels-tab-general')),
        findsOneWidget,
      );
    });

    testWidgets('no swipe action on read channel (swipe disabled)', (
      tester,
    ) async {
      ChannelScopeId? markedReadScopeId;

      await tester.pumpWidget(buildApp(
        homeRepository: const _FakeHomeRepository(snapshot),
        // No inbox override — 'general' has no unread.
        onMarkRead: (scopeId) => markedReadScopeId = scopeId,
      ));
      await tester.pumpAndSettle();

      // 'general' has no unread — swipe should not trigger mark-read.
      await tester.fling(
        find.byKey(const ValueKey('channels-tab-general')),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(markedReadScopeId, isNull);
    });

    testWidgets('SwipeToMarkRead wraps unread channel row', (tester) async {
      await tester.pumpWidget(buildApp(
        homeRepository: const _FakeHomeRepository(snapshot),
        inboxState: inboxWithGeneralUnread(2),
        onMarkRead: (_) {},
      ));
      await tester.pumpAndSettle();

      // The Dismissible wrapper should be present for the unread channel.
      expect(
        find.byKey(const ValueKey('swipe-action-general')),
        findsOneWidget,
      );
    });
  });
}

// ---- Fakes ----

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this.snapshot);
  final HomeWorkspaceSnapshot snapshot;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async =>
      snapshot;

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
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}
