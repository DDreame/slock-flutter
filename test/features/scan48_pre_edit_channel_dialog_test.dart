import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/channels/data/available_channel.dart';
import 'package:slock_app/features/channels/data/channel_management_repository.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/channels/presentation/widgets/channel_management_dialogs.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
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
  // ---------------------------------------------------------------
  // Group 1: Dialog-level tests (EditChannelDialog widget in isolation)
  // ---------------------------------------------------------------

  Widget buildDialog({
    String currentName = 'general',
    String? currentDescription,
    bool currentIsPrivate = false,
    bool isSubmitting = false,
    ValueChanged<EditChannelResult>? onSave,
    VoidCallback? onCancel,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => EditChannelDialog(
            currentName: currentName,
            currentDescription: currentDescription,
            currentIsPrivate: currentIsPrivate,
            isSubmitting: isSubmitting,
            onSave: onSave ?? (_) {},
            onCancel: onCancel ?? () {},
          ),
        ),
      ),
    );
  }

  group('EditChannelDialog expanded fields', () {
    testWidgets('pre-fills description from currentDescription',
        (tester) async {
      await tester.pumpWidget(buildDialog(
        currentDescription: 'Team discussions',
      ));
      await tester.pumpAndSettle();

      final descriptionField = tester.widget<TextField>(
        find.byKey(const ValueKey('edit-channel-description')),
      );
      expect(descriptionField.controller!.text, 'Team discussions');
    });

    testWidgets('pre-fills isPrivate switch from currentIsPrivate',
        (tester) async {
      await tester.pumpWidget(buildDialog(
        currentIsPrivate: true,
      ));
      await tester.pumpAndSettle();

      final switchTile = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('edit-channel-private-switch')),
      );
      expect(switchTile.value, isTrue);
    });

    testWidgets('save button disabled when no changes made', (tester) async {
      await tester.pumpWidget(buildDialog(
        currentName: 'general',
        currentDescription: 'Original desc',
        currentIsPrivate: false,
      ));
      await tester.pumpAndSettle();

      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('save button enabled when description changes', (tester) async {
      await tester.pumpWidget(buildDialog(
        currentName: 'general',
        currentDescription: 'Original desc',
        currentIsPrivate: false,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('edit-channel-description')),
        'Updated desc',
      );
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('save button enabled when isPrivate toggled', (tester) async {
      await tester.pumpWidget(buildDialog(
        currentName: 'general',
        currentDescription: null,
        currentIsPrivate: false,
      ));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('edit-channel-private-switch')));
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('onSave receives EditChannelResult with all fields',
        (tester) async {
      EditChannelResult? receivedResult;
      await tester.pumpWidget(buildDialog(
        currentName: 'general',
        currentDescription: 'Old desc',
        currentIsPrivate: false,
        onSave: (result) => receivedResult = result,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('edit-channel-name')),
        'engineering',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-channel-description')),
        'New desc',
      );
      await tester
          .tap(find.byKey(const ValueKey('edit-channel-private-switch')));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();

      expect(receivedResult, isNotNull);
      expect(receivedResult!.name, 'engineering');
      expect(receivedResult!.description, 'New desc');
      expect(receivedResult!.isPrivate, isTrue);
    });

    testWidgets('save button disabled when name cleared (validation)',
        (tester) async {
      await tester.pumpWidget(buildDialog(
        currentName: 'general',
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('edit-channel-name')),
        '',
      );
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('ZH locale renders Chinese labels for new fields',
        (tester) async {
      await tester.pumpWidget(buildDialog(
        locale: const Locale('zh'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('描述'), findsOneWidget);
      expect(find.text('Description'), findsNothing);
      expect(find.text('私密频道'), findsOneWidget);
      expect(find.text('Private channel'), findsNothing);
    });
  });

  // ---------------------------------------------------------------
  // Group 2: Page-level tests (delta-only PATCH through real UI)
  // ---------------------------------------------------------------

  group('ChannelsTabPage edit dialog delta-only update', () {
    const serverId = ServerScopeId('server-1');

    const channelWithDescription = HomeChannelSummary(
      scopeId: ChannelScopeId(serverId: serverId, value: 'engineering'),
      name: 'engineering',
      description: 'Team engineering discussions',
      isPrivate: false,
    );

    const snapshot = HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: [channelWithDescription],
      directMessages: [],
    );

    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget buildPage({
      required _CapturingChannelManagementRepository repo,
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
          homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          sharedPreferencesProvider.overrideWithValue(prefs),
          appLocalizationsProvider.overrideWithValue(
            lookupAppLocalizations(const Locale('en')),
          ),
          activeServerScopeIdProvider.overrideWithValue(serverId),
          homeRepositoryProvider
              .overrideWithValue(const _FakeHomeRepository(snapshot)),
          sidebarOrderRepositoryProvider
              .overrideWithValue(_FakeSidebarOrderRepository()),
          agentsRepositoryProvider
              .overrideWithValue(const _FakeAgentsRepository()),
          tasksRepositoryProvider
              .overrideWithValue(const _FakeTasksRepository()),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          channelMutedIdsProvider.overrideWith((ref) => <String>{}),
          channelManagementRepositoryProvider.overrideWithValue(repo),
          inboxRepositoryProvider.overrideWithValue(_FakeInboxRepository()),
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

    testWidgets(
        'description-only change sends description but not name/isPrivate',
        (tester) async {
      final repo = _CapturingChannelManagementRepository();
      await tester.pumpWidget(buildPage(repo: repo));
      await tester.pumpAndSettle();

      // Long-press the channel row to open action sheet.
      await tester
          .longPress(find.byKey(const ValueKey('channels-tab-engineering')));
      await tester.pumpAndSettle();

      // Tap edit.
      await tester.tap(find.byKey(const ValueKey('channel-action-edit')));
      await tester.pumpAndSettle();

      // Dialog should be open with pre-filled description.
      expect(find.byKey(const ValueKey('edit-channel-dialog')), findsOneWidget);
      final descField = tester.widget<TextField>(
        find.byKey(const ValueKey('edit-channel-description')),
      );
      expect(descField.controller!.text, 'Team engineering discussions');

      // Change only description.
      await tester.enterText(
        find.byKey(const ValueKey('edit-channel-description')),
        'Updated discussions',
      );
      await tester.pump();

      // Tap save.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // Assert: updateChannel called with description only.
      expect(repo.updateCalls, hasLength(1));
      final call = repo.updateCalls.first;
      expect(call.channelId, 'engineering');
      expect(call.description, 'Updated discussions');
      // Name and isPrivate should be null (unchanged).
      expect(call.name, isNull);
      expect(call.isPrivate, isNull);
    });

    testWidgets('name-only change sends name but not description/isPrivate',
        (tester) async {
      final repo = _CapturingChannelManagementRepository();
      await tester.pumpWidget(buildPage(repo: repo));
      await tester.pumpAndSettle();

      // Long-press the channel row to open action sheet.
      await tester
          .longPress(find.byKey(const ValueKey('channels-tab-engineering')));
      await tester.pumpAndSettle();

      // Tap edit.
      await tester.tap(find.byKey(const ValueKey('channel-action-edit')));
      await tester.pumpAndSettle();

      // Change only name.
      await tester.enterText(
        find.byKey(const ValueKey('edit-channel-name')),
        'backend',
      );
      await tester.pump();

      // Tap save.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // Assert: updateChannel called with name only.
      expect(repo.updateCalls, hasLength(1));
      final call = repo.updateCalls.first;
      expect(call.channelId, 'engineering');
      expect(call.name, 'backend');
      // Description and isPrivate should be null (unchanged).
      expect(call.description, isNull);
      expect(call.isPrivate, isNull);
    });
  });

  // ---------------------------------------------------------------
  // Group 3: HomeChannelSummary.description JSON parsing
  // ---------------------------------------------------------------

  group('HomeChannelSummary.description parsing', () {
    const serverId = ServerScopeId('server-1');
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('parses description from channel JSON item', () {
      final payload = [
        {
          'id': 'ch-1',
          'name': 'general',
          'description': 'Main channel for team',
          'isPrivate': false,
        },
      ];

      final result = parseChannelSummaries(
        payload,
        serverId: serverId,
        l10n: l10n,
      );

      expect(result.channels, hasLength(1));
      expect(result.channels.first.description, 'Main channel for team');
    });

    test('description is null when JSON field absent', () {
      final payload = [
        {
          'id': 'ch-2',
          'name': 'random',
          'isPrivate': true,
        },
      ];

      final result = parseChannelSummaries(
        payload,
        serverId: serverId,
        l10n: l10n,
      );

      expect(result.channels, hasLength(1));
      expect(result.channels.first.description, isNull);
      expect(result.channels.first.name, 'random');
    });

    test('description is null when JSON field is null', () {
      final payload = [
        {
          'id': 'ch-3',
          'name': 'support',
          'description': null,
        },
      ];

      final result = parseChannelSummaries(
        payload,
        serverId: serverId,
        l10n: l10n,
      );

      expect(result.channels, hasLength(1));
      expect(result.channels.first.description, isNull);
    });
  });
}

// --------------- Fakes ---------------

class _UpdateCall {
  _UpdateCall({
    required this.serverId,
    required this.channelId,
    this.name,
    this.description,
    this.isPrivate,
  });

  final ServerScopeId serverId;
  final String channelId;
  final String? name;
  final String? description;
  final bool? isPrivate;
}

class _CapturingChannelManagementRepository
    implements ChannelManagementRepository {
  final List<_UpdateCall> updateCalls = [];

  @override
  Future<List<AvailableChannel>> loadAvailableChannels(
    ServerScopeId serverId,
  ) async =>
      [];

  @override
  Future<String> createChannel(
    ServerScopeId serverId, {
    required String name,
    String? description,
    bool? isPrivate,
  }) async =>
      'new-id';

  @override
  Future<void> updateChannel(
    ServerScopeId serverId, {
    required String channelId,
    String? name,
    String? description,
    bool? isPrivate,
  }) async {
    updateCalls.add(_UpdateCall(
      serverId: serverId,
      channelId: channelId,
      name: name,
      description: description,
      isPrivate: isPrivate,
    ));
  }

  @override
  Future<void> deleteChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> joinChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> leaveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> stopAllAgents(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> resumeAllAgents(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> archiveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> unarchiveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}
}

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
      _snapshot;

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
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) async =>
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
  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async =>
      const InboxResponse(
        items: [],
        totalCount: 0,
        totalUnreadCount: 0,
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
}
