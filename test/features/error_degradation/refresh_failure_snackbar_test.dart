// ---------------------------------------------------------------------------
// #493: Widget-level tests for INV-NET-DEGRADE-2 snackbar behavior.
//
// Verifies that each affected page:
// 1. Shows a refresh-failure snackbar when isRefreshing transitions false
//    with non-null failure and status == success (stale data visible).
// 2. Does NOT show snackbar on mutation failures (isRefreshing never touched).
// 3. Keeps stale data visible during the error state.
// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/l10n/app_localizations.dart';

// Agents
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page.dart';

// Tasks
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';

// Channels / DMs / Home — all use HomeListStore
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/dms/presentation/page/dms_tab_page.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/persisted_agent_names.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';

// Inbox
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';

// Conversation
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';

// Servers
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _sampleAgent = AgentItem(
  id: 'agent-1',
  name: 'Bot',
  model: 'sonnet',
  runtime: 'claude',
  status: 'active',
  activity: 'online',
);

final _sampleTask = TaskItem(
  id: 'task-1',
  title: 'Sample task',
  status: 'in_progress',
  channelId: 'ch-1',
  channelType: 'channel',
  messageId: 'msg-1',
  taskNumber: 1,
  createdById: 'user-1',
  createdByName: 'User',
  createdByType: 'human',
  createdAt: DateTime(2024),
);

const _sampleInboxItem = InboxItem(
  kind: InboxItemKind.channel,
  channelId: 'ch-1',
  channelName: 'general',
  unreadCount: 2,
);

// ---------------------------------------------------------------------------
// Shared helper: pump + trigger + verify
// ---------------------------------------------------------------------------

/// Pumps enough frames for Riverpod state propagation + snackbar animation.
Future<void> _pumpForSnackbar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ---------------------------------------------------------------------------
// Fake stores
// ---------------------------------------------------------------------------

class _FakeAgentsStore extends AgentsStore {
  @override
  AgentsState build() => const AgentsState(
        status: AgentsStatus.success,
        items: [_sampleAgent],
      );

  @override
  Future<void> load() async {}

  /// Simulates a refresh completion with failure.
  void triggerRefreshFailure() {
    state = state.copyWith(isRefreshing: true, clearFailure: true);
    Future.microtask(() {
      state = state.copyWith(
        isRefreshing: false,
        failure: const ServerFailure(
          message: 'Network error',
          statusCode: 500,
        ),
      );
    });
  }

  /// Simulates a mutation error (e.g. createAgent failure).
  /// Sets failure WITHOUT touching isRefreshing.
  void triggerMutationFailure() {
    state = state.copyWith(
      failure: const ServerFailure(
        message: 'Create failed',
        statusCode: 400,
      ),
    );
  }
}

class _FakeHomeListStore extends HomeListStore {
  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
      );

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh({String reason = 'manual'}) async {}

  void triggerRefreshFailure() {
    state = state.copyWith(isRefreshing: true, clearFailure: true);
    Future.microtask(() {
      state = state.copyWith(
        isRefreshing: false,
        failure: const ServerFailure(
          message: 'Network error',
          statusCode: 500,
        ),
      );
    });
  }
}

class _FakeTasksStore extends TasksStore {
  @override
  TasksState build() => TasksState(
        status: TasksStatus.success,
        items: [_sampleTask],
      );

  @override
  Future<void> load() async {}

  void triggerRefreshFailure() {
    state = state.copyWith(isRefreshing: true, clearFailure: true);
    Future.microtask(() {
      state = state.copyWith(
        isRefreshing: false,
        failure: const ServerFailure(
          message: 'Network error',
          statusCode: 500,
        ),
      );
    });
  }
}

class _FakeInboxStore extends InboxStore {
  @override
  InboxState build() => const InboxState(
        status: InboxStatus.success,
        items: [_sampleInboxItem],
        totalCount: 1,
        totalUnreadCount: 2,
      );

  @override
  Future<void> load({InboxFilter? filter}) async {}

  @override
  Future<void> refresh({String reason = 'manual'}) async {}

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> setFilter(InboxFilter filter) async {}

  @override
  Future<void> markRead({required String channelId}) async {}

  @override
  Future<void> markDone({required String channelId}) async {}

  @override
  Future<void> markAllRead() async {}

  void triggerRefreshFailure() {
    state = state.copyWith(isRefreshing: true, clearFailure: true);
    Future.microtask(() {
      state = state.copyWith(
        isRefreshing: false,
        failure: const ServerFailure(
          message: 'Network error',
          statusCode: 500,
        ),
      );
    });
  }
}

class _FakeConversationDetailStore extends ConversationDetailStore {
  @override
  ConversationDetailState build() => ConversationDetailState(
        status: ConversationDetailStatus.success,
        target: ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-1',
          ),
        ),
      );

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> refresh({String reason = 'manual'}) async {}

  @override
  Future<void> loadOlder() async {}

  @override
  Future<void> loadNewer() async {}

  void triggerRefreshFailure() {
    state = state.copyWith(isRefreshing: true, clearFailure: true);
    Future.microtask(() {
      state = state.copyWith(
        isRefreshing: false,
        failure: const ServerFailure(
          message: 'Network error',
          statusCode: 500,
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // Common MaterialApp wrapper with l10n support.
  Widget wrapApp({
    required List<Override> overrides,
    required Widget home,
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TickerMode(enabled: false, child: home),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // 1. AgentsPage
  // -----------------------------------------------------------------------
  group('AgentsPage refresh failure snackbar (#493)', () {
    late _FakeAgentsStore store;
    late List<Override> overrides;

    setUp(() {
      store = _FakeAgentsStore();
      overrides = [
        agentsStoreProvider.overrideWith(() => store),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
        sharedPreferencesProvider.overrideWithValue(prefs),
        realtimeReductionIngressProvider
            .overrideWithValue(RealtimeReductionIngress()),
      ];
    });

    testWidgets(
      'shows snackbar on refresh failure with stale data',
      (tester) async {
        await tester.pumpWidget(wrapApp(
          overrides: overrides,
          home: const AgentsPage(),
        ));
        await tester.pumpAndSettle();

        // Verify stale data is visible.
        expect(find.text('Bot'), findsOneWidget);

        // Trigger refresh failure.
        store.triggerRefreshFailure();
        await _pumpForSnackbar(tester);

        // Snackbar must appear.
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('Could not refresh. Showing cached data.'),
          findsOneWidget,
          reason: 'INV-NET-DEGRADE-2: snackbar must show l10n text',
        );

        // Stale data must remain visible.
        expect(find.text('Bot'), findsOneWidget,
            reason: 'INV-NET-DEGRADE-1: stale data preserved');
      },
    );

    testWidgets(
      'does NOT show snackbar on mutation failure (no isRefreshing)',
      (tester) async {
        await tester.pumpWidget(wrapApp(
          overrides: overrides,
          home: const AgentsPage(),
        ));
        await tester.pumpAndSettle();

        // Trigger mutation failure (no isRefreshing transition).
        store.triggerMutationFailure();
        await _pumpForSnackbar(tester);

        // Snackbar must NOT appear.
        expect(find.byType(SnackBar), findsNothing,
            reason: 'Mutation failures must not trigger refresh snackbar');
      },
    );

    testWidgets(
      'snackbar retry action text is present',
      (tester) async {
        await tester.pumpWidget(wrapApp(
          overrides: overrides,
          home: const AgentsPage(),
        ));
        await tester.pumpAndSettle();

        store.triggerRefreshFailure();
        await _pumpForSnackbar(tester);

        expect(find.text('Retry'), findsOneWidget,
            reason: 'Snackbar must have Retry action');
      },
    );
  });

  // -----------------------------------------------------------------------
  // 2. TasksPage
  // -----------------------------------------------------------------------
  group('TasksPage refresh failure snackbar (#493)', () {
    late _FakeTasksStore store;
    late _FakeHomeListStore homeStore;
    late List<Override> overrides;

    setUp(() {
      store = _FakeTasksStore();
      homeStore = _FakeHomeListStore();
      overrides = [
        tasksStoreProvider.overrideWith(() => store),
        routedTaskEventProvider.overrideWith((ref) => null),
        homeListStoreProvider.overrideWith(() => homeStore),
        crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        realtimeReductionIngressProvider
            .overrideWithValue(RealtimeReductionIngress()),
      ];
    });

    testWidgets(
      'shows snackbar on refresh failure with stale data',
      (tester) async {
        await tester.pumpWidget(wrapApp(
          overrides: overrides,
          home: const TasksPage(serverId: 'server-1'),
        ));
        await tester.pumpAndSettle();

        store.triggerRefreshFailure();
        await _pumpForSnackbar(tester);

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('Could not refresh. Showing cached data.'),
          findsOneWidget,
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // 3. ChannelsTabPage
  // -----------------------------------------------------------------------
  group('ChannelsTabPage refresh failure snackbar (#493)', () {
    late _FakeHomeListStore store;
    late _FakeInboxStore inboxStore;
    late List<Override> overrides;

    setUp(() {
      store = _FakeHomeListStore();
      inboxStore = _FakeInboxStore();
      overrides = [
        homeListStoreProvider.overrideWith(() => store),
        inboxStoreProvider.overrideWith(() => inboxStore),
        activeServerScopeIdProvider
            .overrideWithValue(const ServerScopeId('server-1')),
        unreadSourceProjectionProvider
            .overrideWithValue(UnreadSourceProjectionState()),
        channelManagementStoreProvider.overrideWith(
          () => _FakeChannelManagementStore(),
        ),
        markChannelReadUseCaseProvider.overrideWithValue((_) {}),
        sharedPreferencesProvider.overrideWithValue(prefs),
        realtimeReductionIngressProvider
            .overrideWithValue(RealtimeReductionIngress()),
      ];
    });

    testWidgets(
      'shows snackbar on refresh failure',
      (tester) async {
        await tester.pumpWidget(wrapApp(
          overrides: overrides,
          home: const ChannelsTabPage(),
        ));
        await tester.pumpAndSettle();

        store.triggerRefreshFailure();
        await _pumpForSnackbar(tester);

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('Could not refresh. Showing cached data.'),
          findsOneWidget,
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // 4. DmsTabPage
  // -----------------------------------------------------------------------
  group('DmsTabPage refresh failure snackbar (#493)', () {
    late _FakeHomeListStore store;
    late _FakeInboxStore inboxStore;
    late List<Override> overrides;

    setUp(() {
      store = _FakeHomeListStore();
      inboxStore = _FakeInboxStore();
      overrides = [
        homeListStoreProvider.overrideWith(() => store),
        inboxStoreProvider.overrideWith(() => inboxStore),
        activeServerScopeIdProvider
            .overrideWithValue(const ServerScopeId('server-1')),
        unreadSourceProjectionProvider
            .overrideWithValue(UnreadSourceProjectionState()),
        persistedAgentNamesProvider.overrideWith(
          () => _FakePersistedAgentNames(),
        ),
        markDmReadUseCaseProvider.overrideWithValue((_) {}),
        sharedPreferencesProvider.overrideWithValue(prefs),
        realtimeReductionIngressProvider
            .overrideWithValue(RealtimeReductionIngress()),
      ];
    });

    testWidgets(
      'shows snackbar on refresh failure',
      (tester) async {
        await tester.pumpWidget(wrapApp(
          overrides: overrides,
          home: const DmsTabPage(),
        ));
        await tester.pumpAndSettle();

        store.triggerRefreshFailure();
        await _pumpForSnackbar(tester);

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('Could not refresh. Showing cached data.'),
          findsOneWidget,
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // 5. HomePage
  // -----------------------------------------------------------------------
  group('HomePage refresh failure snackbar (#493)', () {
    late _FakeHomeListStore store;
    late _FakeInboxStore inboxStore;
    late _FakeAgentsStore agentsStore;
    late List<Override> overrides;

    setUp(() {
      store = _FakeHomeListStore();
      inboxStore = _FakeInboxStore();
      agentsStore = _FakeAgentsStore();
      overrides = [
        homeListStoreProvider.overrideWith(() => store),
        inboxStoreProvider.overrideWith(() => inboxStore),
        agentsStoreProvider.overrideWith(() => agentsStore),
        activeServerScopeIdProvider
            .overrideWithValue(const ServerScopeId('server-1')),
        unreadSourceProjectionProvider
            .overrideWithValue(UnreadSourceProjectionState()),
        serverListStoreProvider.overrideWith(() => _FakeServerListStore()),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
        sharedPreferencesProvider.overrideWithValue(prefs),
        realtimeReductionIngressProvider
            .overrideWithValue(RealtimeReductionIngress()),
      ];
    });

    testWidgets(
      'shows snackbar on refresh failure',
      (tester) async {
        await tester.pumpWidget(wrapApp(
          overrides: overrides,
          home: const HomePage(),
        ));
        await tester.pumpAndSettle();

        store.triggerRefreshFailure();
        await _pumpForSnackbar(tester);

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('Could not refresh. Showing cached data.'),
          findsOneWidget,
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // 6. InboxPage
  // -----------------------------------------------------------------------
  group('InboxPage refresh failure snackbar (#493)', () {
    late _FakeInboxStore store;
    late List<Override> overrides;

    setUp(() {
      store = _FakeInboxStore();
      overrides = [
        inboxStoreProvider.overrideWith(() => store),
        inboxProjectionProvider.overrideWithValue(const []),
        activeServerScopeIdProvider
            .overrideWithValue(const ServerScopeId('server-1')),
        sharedPreferencesProvider.overrideWithValue(prefs),
        realtimeReductionIngressProvider
            .overrideWithValue(RealtimeReductionIngress()),
      ];
    });

    testWidgets(
      'shows snackbar on refresh failure with stale data',
      (tester) async {
        await tester.pumpWidget(wrapApp(
          overrides: overrides,
          home: const InboxPage(),
        ));
        await tester.pumpAndSettle();

        store.triggerRefreshFailure();
        await _pumpForSnackbar(tester);

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('Could not refresh. Showing cached data.'),
          findsOneWidget,
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // 7. ConversationDetailPage
  // -----------------------------------------------------------------------
  group('ConversationDetailPage refresh failure snackbar (#493)', () {
    late _FakeConversationDetailStore store;
    late List<Override> overrides;

    setUp(() {
      store = _FakeConversationDetailStore();
      overrides = [
        conversationDetailStoreProvider.overrideWith(() => store),
        conversationDetailSessionStoreProvider
            .overrideWith(() => _FakeConversationDetailSessionStore()),
        voiceMessageStoreProvider.overrideWith(() => _FakeVoiceMessageStore()),
        activeServerScopeIdProvider
            .overrideWithValue(const ServerScopeId('server-1')),
        sharedPreferencesProvider.overrideWithValue(prefs),
        realtimeReductionIngressProvider
            .overrideWithValue(RealtimeReductionIngress()),
      ];
    });

    testWidgets(
      'shows snackbar on refresh failure',
      (tester) async {
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-1',
          ),
        );

        await tester.pumpWidget(wrapApp(
          overrides: overrides,
          home: ConversationDetailPage(
            target: target,
            registerOpenTarget: false,
          ),
        ));
        await tester.pumpAndSettle();

        store.triggerRefreshFailure();
        await _pumpForSnackbar(tester);

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('Could not refresh. Showing cached data.'),
          findsOneWidget,
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Supporting fakes for secondary providers
// ---------------------------------------------------------------------------

class _FakeChannelManagementStore extends ChannelManagementStore {
  @override
  ChannelManagementState build() => const ChannelManagementState();
}

class _FakePersistedAgentNames extends PersistedAgentNames {
  @override
  Set<String> build() => const {};
}

class _FakeServerListStore extends ServerListStore {
  @override
  ServerListState build() => const ServerListState();

  @override
  Future<void> load() async {}
}

class _FakeConversationDetailSessionStore
    extends ConversationDetailSessionStore {
  @override
  Map<ConversationDetailTarget, ConversationDetailSessionEntry> build() =>
      const {};
}

class _FakeVoiceMessageStore extends VoiceMessageStore {
  @override
  VoiceMessageState build() => const VoiceMessageState();
}
