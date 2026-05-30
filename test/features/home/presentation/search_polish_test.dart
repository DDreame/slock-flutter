// ignore_for_file: unused_local_variable
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/dms/presentation/page/dms_tab_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildChannelsApp({
    required HomeRepository homeRepository,
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
          builder: (_, __) => const Scaffold(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appLocalizationsProvider.overrideWithValue(
          lookupAppLocalizations(const Locale('en')),
        ),
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
        channelMutedIdsProvider.overrideWith((ref) => <String>{}),
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

  Widget buildDmsApp({
    required HomeRepository homeRepository,
  }) {
    final router = GoRouter(
      initialLocation: '/dms',
      routes: [
        GoRoute(
          path: '/dms',
          builder: (_, __) => const DmsTabPage(),
        ),
        GoRoute(
          path: '/servers/:serverId/dms/:dmId',
          builder: (_, __) => const Scaffold(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appLocalizationsProvider.overrideWithValue(
          lookupAppLocalizations(const Locale('en')),
        ),
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
        channelMutedIdsProvider.overrideWith((ref) => <String>{}),
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

  group('Search polish — channels', () {
    testWidgets(
      'T1: query toLowerCase called once outside loop (channels filter)',
      (tester) async {
        // Arrange — 50 channels, type a search query.
        final channels = List.generate(
          50,
          (i) => HomeChannelSummary(
            scopeId: ChannelScopeId(serverId: serverId, value: 'ch-$i'),
            name: 'Channel-$i',
          ),
        );
        final snapshot = HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: channels,
          directMessages: const [],
        );

        await tester.pumpWidget(
          buildChannelsApp(
            homeRepository: _FakeHomeRepository(snapshot),
          ),
        );
        await tester.pumpAndSettle();

        // Type search query.
        await tester.enterText(
          find.byKey(const ValueKey('channels-tab-search')),
          'channel-1',
        );
        await tester.pump();

        // Assert: filter works correctly — channels whose name contains
        // 'channel-1' (case-insensitive) are shown.
        // Phase B verifies the hoisted toLowerCase() optimization.
        expect(find.text('Channel-1'), findsOneWidget);
        expect(find.text('Channel-10'), findsOneWidget);
      },
    );

    testWidgets(
      'T2: query toLowerCase called once outside loop (DMs filter)',
      (tester) async {
        // Arrange — multiple DMs, type a search query.
        final dms = List.generate(
          20,
          (i) => HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-$i'),
            title: 'User-$i',
          ),
        );
        final snapshot = HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: const [],
          directMessages: dms,
        );

        await tester.pumpWidget(
          buildDmsApp(
            homeRepository: _FakeHomeRepository(snapshot),
          ),
        );
        await tester.pumpAndSettle();

        // Type search query.
        await tester.enterText(
          find.byKey(const ValueKey('dms-tab-search')),
          'user-1',
        );
        await tester.pump();

        // Assert: filter works correctly.
        expect(find.text('User-1'), findsOneWidget);
        expect(find.text('User-10'), findsOneWidget);
      },
    );
  });

  group('Search polish — clear button', () {
    testWidgets(
      'T3: search field has clear button when text is present',
      (tester) async {
        const snapshot = HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(serverId: serverId, value: 'ch-1'),
              name: 'general',
            ),
          ],
          directMessages: [],
        );

        await tester.pumpWidget(
          buildChannelsApp(
            homeRepository: const _FakeHomeRepository(snapshot),
          ),
        );
        await tester.pumpAndSettle();

        // Enter text into search field.
        await tester.enterText(
          find.byKey(const ValueKey('channels-tab-search')),
          'test',
        );
        await tester.pump();

        // Assert clear button is visible.
        final clearButton = find.byKey(const ValueKey('search-clear-button'));
        expect(clearButton, findsOneWidget);

        // Tap clear button — text should be cleared.
        await tester.tap(clearButton);
        await tester.pump();

        // Search field should be empty again.
        final textField = tester.widget<TextField>(
          find.byKey(const ValueKey('channels-tab-search')),
        );
        expect(textField.controller?.text ?? '', isEmpty);
      },
    );

    testWidgets(
      'T4: clear button has accessibility tooltip',
      (tester) async {
        const snapshot = HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(serverId: serverId, value: 'ch-1'),
              name: 'general',
            ),
          ],
          directMessages: [],
        );

        await tester.pumpWidget(
          buildChannelsApp(
            homeRepository: const _FakeHomeRepository(snapshot),
          ),
        );
        await tester.pumpAndSettle();

        // Enter text to make clear button appear.
        await tester.enterText(
          find.byKey(const ValueKey('channels-tab-search')),
          'test',
        );
        await tester.pump();

        // Find clear button and verify tooltip/semantics.
        final clearButton = find.byKey(const ValueKey('search-clear-button'));
        expect(clearButton, findsOneWidget);

        // Assert tooltip is present for accessibility.
        final tooltipFinder = find.ancestor(
          of: clearButton,
          matching: find.byType(Tooltip),
        );
        expect(
          tooltipFinder,
          findsOneWidget,
          reason: 'Clear button must have a Tooltip for accessibility',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes — copied from channels_tab_page_test.dart with correct interfaces
// ---------------------------------------------------------------------------

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this._snapshot);

  final HomeWorkspaceSnapshot _snapshot;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async =>
      _snapshot;

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
