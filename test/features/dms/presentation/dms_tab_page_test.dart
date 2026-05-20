import 'dart:async';

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
import 'package:slock_app/features/dms/presentation/page/dms_tab_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const serverId = ServerScopeId('server-1');

  const dmAlice = HomeDirectMessageSummary(
    scopeId: DirectMessageScopeId(
      serverId: serverId,
      value: 'dm-alice',
    ),
    title: 'Alice',
  );

  const dmBob = HomeDirectMessageSummary(
    scopeId: DirectMessageScopeId(
      serverId: serverId,
      value: 'dm-bob',
    ),
    title: 'Bob',
  );

  const dmCharlie = HomeDirectMessageSummary(
    scopeId: DirectMessageScopeId(
      serverId: serverId,
      value: 'dm-charlie',
    ),
    title: 'Charlie',
  );

  const dmAgentBot = HomeDirectMessageSummary(
    scopeId: DirectMessageScopeId(
      serverId: serverId,
      value: 'dm-bot',
    ),
    title: 'BotAlpha',
    isAgent: true,
  );

  const sampleSnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [],
    directMessages: [dmAlice, dmBob],
  );

  const crossKindSnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [
      HomeChannelSummary(
        scopeId: ChannelScopeId(
          serverId: serverId,
          value: 'general',
        ),
        name: 'general',
      ),
    ],
    directMessages: [dmAlice],
  );

  const threeDmSnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [],
    directMessages: [dmAlice, dmBob, dmCharlie],
  );

  const emptySnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [],
    directMessages: [],
  );

  Widget buildApp({
    required HomeRepository homeRepository,
    ServerScopeId? activeServerId = serverId,
    GoRouter? router,
    MemberRepository? memberRepository,
    InboxRepository? inboxRepository,
  }) {
    final effectiveRouter = router ??
        GoRouter(
          initialLocation: '/dms',
          routes: [
            GoRoute(
              path: '/dms',
              builder: (_, __) => const DmsTabPage(),
            ),
            GoRoute(
              path: '/servers/:serverId/dms/:channelId',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Text(
                    'dm:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
                  ),
                ),
              ),
            ),
          ],
        );

    return ProviderScope(
      overrides: [
        homeNowProvider.overrideWith(
          (ref) => Stream.value(DateTime.now()),
        ),
        activeServerScopeIdProvider.overrideWithValue(activeServerId),
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
        homeMachineCountLoaderProvider.overrideWithValue(
          (_) async => 0,
        ),
        if (memberRepository != null)
          memberRepositoryProvider.overrideWithValue(memberRepository),
        if (inboxRepository != null)
          inboxRepositoryProvider.overrideWithValue(inboxRepository),
      ],
      child: MaterialApp.router(
        routerConfig: effectiveRouter,
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('renders DM rows when data loads', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-bob')),
      findsOneWidget,
    );
  });

  testWidgets('shows empty state when no DMs', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(emptySnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-empty')),
      findsOneWidget,
    );
    expect(find.text('No direct messages yet.'), findsOneWidget);
  });

  testWidgets('shows no-server state when activeServer is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
        activeServerId: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
      findsNothing,
    );
  });

  testWidgets('preserves original order when all DMs are read', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(threeDmSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-bob')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-charlie')),
      findsOneWidget,
    );

    final aliceOffset = tester.getTopLeft(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
    );
    final bobOffset = tester.getTopLeft(
      find.byKey(const ValueKey('dms-tab-dm-bob')),
    );
    final charlieOffset = tester.getTopLeft(
      find.byKey(const ValueKey('dms-tab-dm-charlie')),
    );

    expect(aliceOffset.dy, lessThan(bobOffset.dy));
    expect(bobOffset.dy, lessThan(charlieOffset.dy));
  });

  testWidgets('search filters DMs by title', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(threeDmSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-bob')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-charlie')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('dms-tab-search')),
      'ali',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-bob')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-charlie')),
      findsNothing,
    );
  });

  testWidgets('search shows empty result text when no match', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('dms-tab-search')),
      'nonexistent',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-search-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
      findsNothing,
    );
  });

  testWidgets('tapping a DM navigates to DM route', (tester) async {
    final router = GoRouter(
      initialLocation: '/dms',
      routes: [
        GoRoute(
          path: '/dms',
          builder: (_, __) => const DmsTabPage(),
        ),
        GoRoute(
          path: '/servers/:serverId/dms/:channelId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'dm:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
    );
    await tester.pumpAndSettle();
    // Elapse the deferred mark-read timer (1 second post-navigation).
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('dm:server-1/dm-alice'), findsOneWidget);
  });

  testWidgets('shows search field', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-search')),
      findsOneWidget,
    );
  });

  testWidgets('shows new message button', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dms-tab-create-button')),
      findsOneWidget,
    );
  });

  testWidgets('refresh indicator triggers data reload', (
    tester,
  ) async {
    final repo = _MutableFakeHomeRepository(sampleSnapshot);

    await tester.pumpWidget(buildApp(homeRepository: repo));
    await tester.pumpAndSettle();

    expect(repo.loadCount, 1);

    await tester.fling(
      find.byKey(const ValueKey('dms-tab-dm-alice')),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(repo.loadCount, greaterThan(1));
  });

  // -----------------------------------------------------------------------
  // INV-REFRESH-SWR-1: Pull-to-refresh does NOT show skeleton flash.
  // -----------------------------------------------------------------------
  testWidgets(
    'pull-to-refresh keeps DM list visible — no skeleton flash '
    '(INV-REFRESH-SWR-1)',
    (tester) async {
      final repo = _MutableFakeHomeRepository(sampleSnapshot);

      await tester.pumpWidget(buildApp(homeRepository: repo));
      await tester.pumpAndSettle();

      // DMs are visible before refresh.
      expect(
        find.byKey(const ValueKey('dms-tab-dm-alice')),
        findsOneWidget,
      );

      // Trigger pull-to-refresh gesture.
      await tester.fling(
        find.byKey(const ValueKey('dms-tab-dm-alice')),
        const Offset(0, 300),
        1000,
      );

      // Pump a single frame (mid-refresh).
      await tester.pump();

      // ASSERT: skeleton must NOT appear.
      expect(
        find.byKey(const ValueKey('dms-skeleton')),
        findsNothing,
        reason: 'Pull-to-refresh must NOT show skeleton — SWR keeps '
            'existing content visible (INV-REFRESH-SWR-1)',
      );

      // ASSERT: DM rows must still be visible.
      expect(
        find.byKey(const ValueKey('dms-tab-dm-alice')),
        findsOneWidget,
        reason: 'DM rows must remain visible during refresh '
            '(INV-REFRESH-SWR-1)',
      );

      await tester.pumpAndSettle();
    },
  );

  testWidgets('new DM navigates to DM route after selecting a member', (
    tester,
  ) async {
    final memberRepo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Alice'),
      ],
      dmChannelId: 'dm-new-123',
    );

    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
        memberRepository: memberRepo,
      ),
    );
    await tester.pumpAndSettle();

    // Tap the "+" new message button
    await tester.tap(find.byKey(const ValueKey('dms-tab-create-button')));
    await tester.pumpAndSettle();

    // Select Alice from the member list
    await tester.tap(find.byKey(const ValueKey('dm-member-u1')));
    await tester.pumpAndSettle();

    // After pop, DmsTabPage calls go('/servers/server-1/dms/dm-new-123')
    expect(find.text('dm:server-1/dm-new-123'), findsOneWidget);
  });

  testWidgets('shows agent badge for DM with isAgent: true', (tester) async {
    const agentSnapshot = HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: [],
      directMessages: [dmAlice, dmAgentBot],
    );

    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(agentSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    // The agent DM row should render the badge.
    expect(
      find.byKey(const ValueKey('dm-agent-badge')),
      findsOneWidget,
    );
    // Verify the agent row is present.
    expect(
      find.byKey(const ValueKey('dms-tab-dm-bot')),
      findsOneWidget,
    );
  });

  testWidgets('does not show agent badge for human DM rows', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    // Neither Alice nor Bob is an agent — no badge should appear.
    expect(
      find.byKey(const ValueKey('dm-agent-badge')),
      findsNothing,
    );
  });

  // -----------------------------------------------------------------
  // Mark-all-read button (INV-MARK-ALL)
  // -----------------------------------------------------------------

  /// Builds a [ProviderContainer] with inbox pre-loaded, then pumps
  /// [DmsTabPage] via [UncontrolledProviderScope].
  Future<ProviderContainer> pumpWithInbox(
    WidgetTester tester, {
    required HomeRepository homeRepository,
    required _FakeInboxRepository inboxRepository,
  }) async {
    final container = ProviderContainer(
      overrides: [
        homeNowProvider.overrideWith(
          (ref) => Stream.value(DateTime.now()),
        ),
        activeServerScopeIdProvider.overrideWithValue(serverId),
        homeRepositoryProvider.overrideWithValue(homeRepository),
        inboxRepositoryProvider.overrideWithValue(inboxRepository),
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
      ],
    );
    addTearDown(container.dispose);

    // Seed InboxStore so unreadSourceProjectionProvider computes.
    await container.read(inboxStoreProvider.notifier).load();

    final router = GoRouter(
      initialLocation: '/dms',
      routes: [
        GoRoute(
          path: '/dms',
          builder: (_, __) => const DmsTabPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'mark-all-read button visible when DM has unread (INV-MARK-ALL-1)',
    (tester) async {
      final inboxRepo = _FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-alice',
              channelName: 'Alice',
              unreadCount: 3,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 3,
          hasMore: false,
        ),
      );

      await pumpWithInbox(
        tester,
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
        inboxRepository: inboxRepo,
      );

      expect(
        find.byKey(const ValueKey('dms-tab-mark-all-read')),
        findsOneWidget,
        reason: 'INV-MARK-ALL-1: Button should be visible when DMs have unread',
      );
    },
  );

  testWidgets(
    'mark-all-read button hidden when no DM unreads (INV-MARK-ALL-1)',
    (tester) async {
      final inboxRepo = _FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-alice',
              channelName: 'Alice',
              unreadCount: 0,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 0,
          hasMore: false,
        ),
      );

      await pumpWithInbox(
        tester,
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
        inboxRepository: inboxRepo,
      );

      expect(
        find.byKey(const ValueKey('dms-tab-mark-all-read')),
        findsNothing,
        reason: 'INV-MARK-ALL-1: Button should be hidden when no DM unreads',
      );
    },
  );

  testWidgets(
    'tapping mark-all-read zeroes DM unread and hides button (INV-MARK-ALL-2)',
    (tester) async {
      final inboxRepo = _FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-alice',
              channelName: 'Alice',
              unreadCount: 5,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 5,
          hasMore: false,
        ),
      );

      await pumpWithInbox(
        tester,
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
        inboxRepository: inboxRepo,
      );

      // Button should be visible before tap.
      expect(
        find.byKey(const ValueKey('dms-tab-mark-all-read')),
        findsOneWidget,
      );

      // Tap the button.
      await tester.tap(
        find.byKey(const ValueKey('dms-tab-mark-all-read')),
      );
      await tester.pumpAndSettle();

      // Button should disappear after optimistic update.
      expect(
        find.byKey(const ValueKey('dms-tab-mark-all-read')),
        findsNothing,
        reason:
            'INV-MARK-ALL-2: Button should disappear after tap (optimistic)',
      );

      // markAllRead should have been called.
      expect(inboxRepo.markAllReadCalled, isTrue,
          reason: 'markAllRead should have been called');
    },
  );

  testWidgets(
    'mark-all-read on DMs tab also clears channel unreads (global call)',
    (tester) async {
      final inboxRepo = _FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-alice',
              channelName: 'Alice',
              unreadCount: 3,
            ),
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'general',
              channelName: 'general',
              unreadCount: 2,
            ),
          ],
          totalCount: 2,
          totalUnreadCount: 5,
          hasMore: false,
        ),
      );

      final container = await pumpWithInbox(
        tester,
        homeRepository: const _FakeHomeRepository(crossKindSnapshot),
        inboxRepository: inboxRepo,
      );

      // Verify both DM and channel unreads exist before tap.
      final projection = container.read(unreadSourceProjectionProvider);
      expect(projection.dmUnreadTotal, 3);
      expect(projection.channelUnreadTotal, 2);

      // Tap the button.
      await tester.tap(
        find.byKey(const ValueKey('dms-tab-mark-all-read')),
      );
      await tester.pumpAndSettle();

      // Global markAllRead clears all kinds.
      final afterProjection = container.read(unreadSourceProjectionProvider);
      expect(afterProjection.dmUnreadTotal, 0,
          reason: 'DM unreads should be zeroed');
      expect(afterProjection.channelUnreadTotal, 0,
          reason:
              'Channel unreads should also be zeroed (global markAllRead clears all)');
    },
  );
}

// ----  Fakes  ----

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this.snapshot);

  final HomeWorkspaceSnapshot snapshot;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(
    ServerScopeId serverId,
  ) async =>
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

class _MutableFakeHomeRepository implements HomeRepository {
  _MutableFakeHomeRepository(this.snapshot);

  final HomeWorkspaceSnapshot snapshot;
  int loadCount = 0;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(
    ServerScopeId serverId,
  ) async {
    loadCount++;
    return snapshot;
  }

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
  Future<SidebarOrder> loadSidebarOrder(
    ServerScopeId serverId,
  ) async =>
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

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({
    this.members = const [],
    this.dmChannelId = 'dm-channel-1',
  });

  final List<MemberProfile> members;
  final String dmChannelId;

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    return members;
  }

  @override
  Future<String> createInvite(ServerScopeId serverId) async {
    return 'invite-code';
  }

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) async {}

  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) async {}

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    return dmChannelId;
  }

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async {
    return dmChannelId;
  }
}

class _FakeInboxRepository implements InboxRepository {
  _FakeInboxRepository({required this.fetchResponse});

  final InboxResponse fetchResponse;
  bool markAllReadCalled = false;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async =>
      fetchResponse;

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
  Future<void> markAllRead(ServerScopeId serverId) async {
    markAllReadCalled = true;
  }
}
