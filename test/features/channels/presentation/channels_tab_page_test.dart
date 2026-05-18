import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/channels/data/channel_management_repository.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/presentation/widgets/home_channel_row.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
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
import 'package:slock_app/l10n/app_localizations_provider.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  const channelGeneral = HomeChannelSummary(
    scopeId: ChannelScopeId(
      serverId: serverId,
      value: 'general',
    ),
    name: 'general',
  );

  const channelRandom = HomeChannelSummary(
    scopeId: ChannelScopeId(
      serverId: serverId,
      value: 'random',
    ),
    name: 'random',
  );

  const channelDesign = HomeChannelSummary(
    scopeId: ChannelScopeId(
      serverId: serverId,
      value: 'design',
    ),
    name: 'design',
  );

  const channelSecret = HomeChannelSummary(
    scopeId: ChannelScopeId(
      serverId: serverId,
      value: 'secret',
    ),
    name: 'secret',
    isPrivate: true,
  );

  const sampleSnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [channelGeneral, channelRandom],
    directMessages: [],
  );

  const crossKindSnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [channelGeneral],
    directMessages: [
      HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(
          serverId: serverId,
          value: 'dm-alice',
        ),
        title: 'Alice',
      ),
    ],
  );

  const threeChannelSnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [channelGeneral, channelRandom, channelDesign],
    directMessages: [],
  );

  const emptySnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [],
    directMessages: [],
  );

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildApp({
    required HomeRepository homeRepository,
    ServerScopeId? activeServerId = serverId,
    ChannelManagementRepository? channelManagementRepository,
    InboxRepository? inboxRepository,
    GoRouter? router,
  }) {
    final effectiveRouter = router ??
        GoRouter(
          initialLocation: '/channels',
          routes: [
            GoRoute(
              path: '/channels',
              builder: (_, __) => const ChannelsTabPage(),
            ),
            GoRoute(
              path: '/servers/:serverId/channels/:channelId',
              builder: (context, state) => Scaffold(
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
        appLocalizationsProvider.overrideWithValue(
          lookupAppLocalizations(const Locale('en')),
        ),
        activeServerScopeIdProvider.overrideWithValue(activeServerId),
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
        if (channelManagementRepository != null)
          channelManagementRepositoryProvider.overrideWithValue(
            channelManagementRepository,
          ),
        if (inboxRepository != null)
          inboxRepositoryProvider.overrideWithValue(inboxRepository),
      ],
      child: MaterialApp.router(
        routerConfig: effectiveRouter,
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('renders channel rows when data loads', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('channels-tab-general')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-random')),
      findsOneWidget,
    );
  });

  testWidgets('shows empty state when no channels', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(emptySnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('channels-tab-empty')),
      findsOneWidget,
    );
    expect(find.text('No channels yet.'), findsOneWidget);
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

    // Should not show channel rows.
    expect(
      find.byKey(const ValueKey('channels-tab-general')),
      findsNothing,
    );
  });

  testWidgets('sorts unread channels before read channels', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(threeChannelSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    // All three channels should be visible.
    expect(
      find.byKey(const ValueKey('channels-tab-general')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-random')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-design')),
      findsOneWidget,
    );

    // Verify the unread-first order by checking widget positions.
    // Without any unreads, the original order should be preserved.
    final generalOffset = tester.getTopLeft(
      find.byKey(const ValueKey('channels-tab-general')),
    );
    final randomOffset = tester.getTopLeft(
      find.byKey(const ValueKey('channels-tab-random')),
    );
    final designOffset = tester.getTopLeft(
      find.byKey(const ValueKey('channels-tab-design')),
    );

    // Original order: general, random, design (all read).
    expect(generalOffset.dy, lessThan(randomOffset.dy));
    expect(randomOffset.dy, lessThan(designOffset.dy));
  });

  testWidgets('search filters channels by name', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(threeChannelSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    // All three channels visible initially.
    expect(
      find.byKey(const ValueKey('channels-tab-general')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-random')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-design')),
      findsOneWidget,
    );

    // Type in the search field.
    await tester.enterText(
      find.byKey(const ValueKey('channels-tab-search')),
      'gen',
    );
    await tester.pumpAndSettle();

    // Only 'general' should remain.
    expect(
      find.byKey(const ValueKey('channels-tab-general')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-random')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-design')),
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
      find.byKey(const ValueKey('channels-tab-search')),
      'nonexistent',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('channels-tab-search-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channels-tab-general')),
      findsNothing,
    );
  });

  testWidgets('tapping a channel navigates to channel route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/channels',
      routes: [
        GoRoute(
          path: '/channels',
          builder: (_, __) => const ChannelsTabPage(),
        ),
        GoRoute(
          path: '/servers/:serverId/channels/:channelId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'channel:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
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
      find.byKey(const ValueKey('channels-tab-general')),
    );
    await tester.pumpAndSettle();
    // Elapse the deferred mark-read timer (1 second post-navigation).
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('channel:server-1/general'), findsOneWidget);
  });

  testWidgets('create button opens create channel page', (
    tester,
  ) async {
    final channelMgmt = _FakeChannelManagementRepository();

    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
        channelManagementRepository: channelMgmt,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('channels-tab-create-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('create-channel-name')),
      findsOneWidget,
    );
  });

  testWidgets(
      'create channel navigates to new channel route after successful create', (
    tester,
  ) async {
    final channelMgmt = _FakeChannelManagementRepository();

    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
        channelManagementRepository: channelMgmt,
      ),
    );
    await tester.pumpAndSettle();

    // Open create channel page
    await tester.tap(
      find.byKey(const ValueKey('channels-tab-create-button')),
    );
    await tester.pumpAndSettle();

    // Fill name and submit
    await tester.enterText(
      find.byKey(const ValueKey('create-channel-name')),
      'design',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('create-channel-submit')));
    await tester.pumpAndSettle();

    // After pop, ChannelsTabPage calls go('/servers/server-1/channels/new-channel-id')
    expect(find.text('channel:server-1/new-channel-id'), findsOneWidget);
  });

  testWidgets('shows search field', (tester) async {
    await tester.pumpWidget(
      buildApp(
        homeRepository: const _FakeHomeRepository(sampleSnapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('channels-tab-search')),
      findsOneWidget,
    );
  });

  testWidgets('refresh indicator triggers data reload', (tester) async {
    final repo = _MutableFakeHomeRepository(sampleSnapshot);

    await tester.pumpWidget(buildApp(homeRepository: repo));
    await tester.pumpAndSettle();

    expect(repo.loadCount, 1);

    // Trigger pull-to-refresh.
    await tester.fling(
      find.byKey(const ValueKey('channels-tab-general')),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(repo.loadCount, greaterThan(1));
  });

  // -----------------------------------------------------------------
  // Mark-all-read button (INV-MARK-ALL)
  // -----------------------------------------------------------------

  /// Builds a [ProviderContainer] with inbox pre-loaded, then pumps
  /// [ChannelsTabPage] via [UncontrolledProviderScope].
  Future<ProviderContainer> pumpWithInbox(
    WidgetTester tester, {
    required HomeRepository homeRepository,
    required _FakeInboxRepository inboxRepository,
  }) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appLocalizationsProvider.overrideWithValue(
          lookupAppLocalizations(const Locale('en')),
        ),
        activeServerScopeIdProvider.overrideWithValue(serverId),
        homeRepositoryProvider.overrideWithValue(homeRepository),
        inboxRepositoryProvider.overrideWithValue(inboxRepository),
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
    );
    addTearDown(container.dispose);

    // Seed InboxStore so unreadSourceProjectionProvider computes.
    await container.read(inboxStoreProvider.notifier).load();

    final router = GoRouter(
      initialLocation: '/channels',
      routes: [
        GoRoute(
          path: '/channels',
          builder: (_, __) => const ChannelsTabPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'mark-all-read button visible when channel has unread (INV-MARK-ALL-1)',
    (tester) async {
      final inboxRepo = _FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'general',
              channelName: 'general',
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
        find.byKey(const ValueKey('channels-tab-mark-all-read')),
        findsOneWidget,
        reason:
            'INV-MARK-ALL-1: Button should be visible when channels have unread',
      );
    },
  );

  testWidgets(
    'mark-all-read button hidden when no channel unreads (INV-MARK-ALL-1)',
    (tester) async {
      final inboxRepo = _FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'general',
              channelName: 'general',
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
        find.byKey(const ValueKey('channels-tab-mark-all-read')),
        findsNothing,
        reason:
            'INV-MARK-ALL-1: Button should be hidden when no channel unreads',
      );
    },
  );

  testWidgets(
    'tapping mark-all-read zeroes unread and hides button (INV-MARK-ALL-2)',
    (tester) async {
      final inboxRepo = _FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'general',
              channelName: 'general',
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
        find.byKey(const ValueKey('channels-tab-mark-all-read')),
        findsOneWidget,
      );

      // Tap the button.
      await tester.tap(
        find.byKey(const ValueKey('channels-tab-mark-all-read')),
      );
      await tester.pumpAndSettle();

      // Button should disappear after optimistic update.
      expect(
        find.byKey(const ValueKey('channels-tab-mark-all-read')),
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
    'mark-all-read on channels tab also clears DM unreads (global call)',
    (tester) async {
      final inboxRepo = _FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'general',
              channelName: 'general',
              unreadCount: 3,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-alice',
              channelName: 'Alice',
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

      // Verify both channel and DM unreads exist before tap.
      final projection = container.read(unreadSourceProjectionProvider);
      expect(projection.channelUnreadTotal, 3);
      expect(projection.dmUnreadTotal, 2);

      // Tap the button.
      await tester.tap(
        find.byKey(const ValueKey('channels-tab-mark-all-read')),
      );
      await tester.pumpAndSettle();

      // Global markAllRead clears all kinds.
      final afterProjection = container.read(unreadSourceProjectionProvider);
      expect(afterProjection.channelUnreadTotal, 0,
          reason: 'Channel unreads should be zeroed');
      expect(afterProjection.dmUnreadTotal, 0,
          reason:
              'DM unreads should also be zeroed (global markAllRead clears all)');
    },
  );

  // -----------------------------------------------------------------
  // Private channel badge (INV-PRIVATE)
  // -----------------------------------------------------------------

  testWidgets(
    'private channel shows lock icon (INV-PRIVATE-1)',
    (tester) async {
      const privateSnapshot = HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: [channelGeneral, channelSecret],
        directMessages: [],
      );

      await tester.pumpWidget(
        buildApp(
          homeRepository: const _FakeHomeRepository(privateSnapshot),
        ),
      );
      await tester.pumpAndSettle();

      // Private channel should show lock icon.
      expect(
        find.byKey(const ValueKey('channel-private-badge')),
        findsOneWidget,
        reason: 'INV-PRIVATE-1: Private channel should show lock icon',
      );
      // Lock icon should be present.
      expect(find.byIcon(Icons.lock), findsOneWidget);
    },
  );

  testWidgets(
    'non-private channel does not show lock icon (INV-PRIVATE-2)',
    (tester) async {
      await tester.pumpWidget(
        buildApp(
          homeRepository: const _FakeHomeRepository(sampleSnapshot),
        ),
      );
      await tester.pumpAndSettle();

      // No private channels — no lock icon.
      expect(
        find.byKey(const ValueKey('channel-private-badge')),
        findsNothing,
        reason: 'INV-PRIVATE-2: Non-private channels should not show lock icon',
      );
      expect(find.byIcon(Icons.lock), findsNothing);
    },
  );

  testWidgets(
    'isPrivate defaults to false when not specified (INV-PRIVATE-3)',
    (tester) async {
      // channelGeneral has no explicit isPrivate — defaults to false.
      const defaultSnapshot = HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: [channelGeneral],
        directMessages: [],
      );

      await tester.pumpWidget(
        buildApp(
          homeRepository: const _FakeHomeRepository(defaultSnapshot),
        ),
      );
      await tester.pumpAndSettle();

      // Should show tag icon, not lock.
      expect(find.byIcon(Icons.tag), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsNothing,
          reason: 'INV-PRIVATE-3: Default isPrivate=false shows tag not lock');
    },
  );

  testWidgets(
    'pinned private channel still shows lock icon (INV-PRIVATE-1)',
    (tester) async {
      // Pinned channels come from SidebarOrder. To test the icon
      // priority directly, we use HomeChannelRow in isolation.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HomeChannelRow(
              channel: channelSecret,
              isPinned: true,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Private indicator must survive pinned state.
      expect(
        find.byKey(const ValueKey('channel-private-badge')),
        findsOneWidget,
        reason:
            'INV-PRIVATE-1: Pinned private channel must still show lock icon',
      );
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.byIcon(Icons.push_pin), findsNothing,
          reason: 'Lock takes priority over pin for private channels');
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

class _FakeChannelManagementRepository implements ChannelManagementRepository {
  _FakeChannelManagementRepository();

  final List<String> createdNames = [];

  @override
  Future<String> createChannel(
    ServerScopeId serverId, {
    required String name,
    String? description,
    bool? isPrivate,
  }) async {
    createdNames.add(name);
    return 'new-channel-id';
  }

  @override
  Future<void> updateChannel(
    ServerScopeId serverId, {
    required String channelId,
    required String name,
  }) async {}

  @override
  Future<void> deleteChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> leaveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}
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
