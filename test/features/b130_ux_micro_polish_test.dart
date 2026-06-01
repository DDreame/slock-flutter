// =============================================================================
// B130 — UX Micro-Polish: load-bearing tests.
//
// 1. Task ref tap — real ConversationDetailPage; shows snackbar on 404
// 2. Non-member notification — real appRouterProvider; shows "no access"
// 3. Task claim 409 — real TasksPage; shows "already claimed"
// 4. Message composer — character counter + send disabled over limit
//
// Each test mounts the REAL production widget and exercises the REAL code path.
// Reverting the production change makes the test RED.
// =============================================================================

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/root_scaffold_messenger.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

import '../stores/session/session_store_persistence_test.dart'
    show FakeAuthRepository;
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';

void main() {
  final testTarget = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('srv-1'),
      value: 'ch-1',
    ),
  );

  // ===========================================================================
  // 1. Message composer max-length (real ConversationComposer widget)
  // ===========================================================================
  group('B130 — Message composer max-length', () {
    Widget buildComposer({required String draft}) {
      final controller = TextEditingController(text: draft);
      return ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: ConversationComposer(
              controller: controller,
              focusNode: FocusNode(),
              state: ConversationDetailState(
                target: testTarget,
                status: ConversationDetailStatus.success,
                draft: draft,
              ),
              isRecording: false,
              isFormattingToolbarVisible: false,
              isEmojiPickerVisible: false,
              onToggleFormattingToolbar: () {},
              onToggleEmojiPicker: () {},
              onChanged: (_) {},
              onSend: () async {},
              onPickAttachment: (_) {},
              onRemoveAttachment: (_) {},
              onCancelUpload: (_) {},
              onClearReply: () {},
              onMicTap: () {},
              onSendRecording: () {},
              onCancelRecording: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('shows character counter when approaching limit',
        (tester) async {
      // 3850 chars = within 200 of 4000 limit → counter should show
      final draft = 'a' * 3850;
      await tester.pumpWidget(buildComposer(draft: draft));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('composer-char-counter')),
        findsOneWidget,
      );
      expect(find.text('3850/4000'), findsOneWidget);
    });

    testWidgets('hides character counter when well under limit',
        (tester) async {
      final draft = 'a' * 100;
      await tester.pumpWidget(buildComposer(draft: draft));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('composer-char-counter')),
        findsNothing,
      );
    });

    testWidgets('shows "Message too long" when over limit', (tester) async {
      final draft = 'a' * 4001;
      await tester.pumpWidget(buildComposer(draft: draft));
      await tester.pumpAndSettle();

      expect(find.text('Message too long'), findsOneWidget);
    });

    testWidgets('send button visible but disabled when over limit',
        (tester) async {
      final draft = 'a' * 4001;
      await tester.pumpWidget(buildComposer(draft: draft));
      await tester.pumpAndSettle();

      // Send button should be visible (not swapped to mic)
      expect(find.byKey(const ValueKey('composer-send')), findsOneWidget);
      expect(find.byKey(const ValueKey('composer-mic')), findsNothing);

      // But disabled (onPressed is null)
      final iconButton = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(const ValueKey('composer-send')),
          matching: find.byType(IconButton),
        ),
      );
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('send button visible when at limit', (tester) async {
      final draft = 'a' * 4000;
      await tester.pumpWidget(buildComposer(draft: draft));
      await tester.pumpAndSettle();

      // Exactly at limit — send should still work
      expect(find.byKey(const ValueKey('composer-send')), findsOneWidget);
    });
  });

  // ===========================================================================
  // 2. Task ref tap error feedback — real ConversationDetailPage
  //
  // Mounts the real ConversationDetailPage which internally constructs
  // ConversationMessageCard. Tapping "task #42" fires the real _onTaskRefTap
  // method. Reverting the catchError → snackbar logic makes these tests RED.
  // ===========================================================================
  group('B130 — Task ref tap error feedback (real ConversationDetailPage)', () {
    testWidgets('shows "Task not found" snackbar on NotFoundFailure',
        (tester) async {
      await tester.pumpWidget(
        _buildConversationApp(
          target: testTarget,
          messageContent: 'Check task #42 status',
          taskRepoOverride: const _NotFoundTasksRepository(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the real task ref chip rendered by ConversationMessageCard
      final taskRefTap = find.byKey(const ValueKey('task-ref-tap-42'));
      expect(taskRefTap, findsOneWidget,
          reason: 'task #42 chip must render from message content');

      await tester.tap(taskRefTap);
      await tester.pumpAndSettle();

      // The real _onTaskRefTap.catchError path shows "Task not found"
      expect(find.text('Task not found'), findsOneWidget);
    });

    testWidgets('shows "Failed to load task" snackbar on generic error',
        (tester) async {
      await tester.pumpWidget(
        _buildConversationApp(
          target: testTarget,
          messageContent: 'Check task #42 status',
          taskRepoOverride: const _GenericErrorTasksRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('task-ref-tap-42')));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load task'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 3. Task claim 409 conflict — real TasksPage
  //
  // Mounts the real TasksPage widget. Taps the "..." actions button then
  // the "Claim" action. The real _claimTask → tasksStoreProvider.notifier
  // path fires. The fake store's claimTask throws ConflictFailure, which the
  // real _TasksScreenState._claimTask catches and shows the snackbar.
  // Reverting the `on ConflictFailure` catch clause makes this test RED.
  // ===========================================================================
  group('B130 — Task claim 409 conflict (real TasksPage)', () {
    testWidgets('shows "already claimed" snackbar on ConflictFailure',
        (tester) async {
      final store = _ConflictClaimTasksStore(
        initialState: TasksState(
          status: TasksStatus.success,
          items: [
            TaskItem(
              id: 'task-1',
              taskNumber: 1,
              title: 'Test task',
              status: 'todo',
              channelId: 'ch-1',
              channelType: 'channel',
              createdById: 'user-1',
              createdByName: 'Alice',
              createdByType: 'human',
              createdAt: DateTime(2026, 6, 1),
              // claimedById: null → claim action visible in sheet
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tasksStoreProvider.overrideWith(() => store),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: const TasksPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pump();

      // Open the action sheet via the "..." button on the task row
      await tester.tap(find.byKey(const ValueKey('task-actions-task-1')));
      await tester.pumpAndSettle();

      // Tap the Claim action in the bottom sheet
      await tester.tap(find.byKey(const ValueKey('task-action-claim')));
      await tester.pumpAndSettle();

      // The real _claimTask catches ConflictFailure → shows l10n snackbar
      expect(
        find.text('This task was already claimed by someone else'),
        findsOneWidget,
      );
    });
  });

  // ===========================================================================
  // 4. Non-member notification — real appRouterProvider
  //
  // Mounts the real GoRouter (from appRouterProvider) with the
  // rootScaffoldMessengerKey wired into MaterialApp.router. Sets a pending
  // notification deep link targeting a server the user is NOT a member of.
  // The real router listener in app_router.dart fires the "no access" snackbar
  // via rootScaffoldMessengerKey. Reverting that branch makes this test RED.
  // ===========================================================================
  group('B130 — Non-member notification (real appRouterProvider)', () {
    testWidgets(
        'shows "no access" snackbar for notification deep link to non-member server',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboardingComplete': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
          serverListRepositoryProvider.overrideWithValue(
            _FakeServerListRepository(['server-1']),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Bootstrap: authenticate and mark ready
      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      await container.read(serverListStoreProvider.notifier).load();
      container.read(appReadyProvider.notifier).state = true;

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            // Wire rootScaffoldMessengerKey — this is how main.dart does it
            scaffoldMessengerKey: rootScaffoldMessengerKey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set a notification deep link targeting a server the user is NOT in.
      // Path must match isNotificationDeepLink but NOT isConversationDeepLink.
      // Using /servers/<non-member>/agents/<id> which is a notification link.
      container.read(pendingDeepLinkProvider.notifier).state =
          '/servers/nonexistent-server/agents/agent-1';
      await tester.pumpAndSettle();

      // The real app_router.dart listener fires the no-access snackbar
      expect(
        find.text("You don't have access to this channel"),
        findsOneWidget,
      );
      // Deep link was consumed
      expect(container.read(pendingDeepLinkProvider), isNull);
    });
  });
}

// =============================================================================
// Helpers — Task ref tap (real ConversationDetailPage)
// =============================================================================

/// Builds a real ConversationDetailPage with a message containing [messageContent].
/// Overrides tasksRepositoryProvider with [taskRepoOverride] to control
/// what happens when the real _onTaskRefTap calls getTaskByNumber.
Widget _buildConversationApp({
  required ConversationDetailTarget target,
  required String messageContent,
  required TasksRepository taskRepoOverride,
}) {
  final conversationRepo = _FakeConversationRepository(
    snapshot: ConversationDetailSnapshot(
      target: target,
      title: '#test-channel',
      messages: [
        ConversationMessageSummary(
          id: 'msg-1',
          content: messageContent,
          createdAt: DateTime.parse('2026-06-01T10:00:00Z'),
          senderId: 'user-2',
          senderType: 'human',
          messageType: 'message',
          senderName: 'Sender',
          seq: 1,
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    ),
  );

  final router = GoRouter(
    initialLocation: '/conversation',
    routes: [
      GoRoute(
        path: '/conversation',
        builder: (_, __) => ConversationDetailPage(target: target),
      ),
      // Stub routes for navigation targets (not relevant for error tests)
      GoRoute(
        path: '/servers/:serverId/tasks',
        builder: (_, __) => const Scaffold(body: Text('tasks-page')),
      ),
      GoRoute(
        path: '/servers/:serverId/channels/:channelId',
        builder: (_, __) => const Scaffold(body: Text('channel-page')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(conversationRepo),
      tasksRepositoryProvider.overrideWithValue(taskRepoOverride),
      channelMemberRepositoryProvider
          .overrideWithValue(const _FakeChannelMemberRepository()),
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      profileRepositoryProvider
          .overrideWithValue(const _FakeProfileRepository()),
      memberRepositoryProvider.overrideWithValue(const _FakeMemberRepository()),
      homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

// =============================================================================
// Fakes — Task ref tap
// =============================================================================

/// Throws NotFoundFailure on getTaskByNumber — simulates 404.
class _NotFoundTasksRepository implements TasksRepository {
  const _NotFoundTasksRepository();

  @override
  Future<TaskItem> getTaskByNumber(
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  }) async {
    throw const NotFoundFailure();
  }

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async => [];
  @override
  Future<List<TaskItem>> createTasks(ServerScopeId serverId,
          {required String channelId, required List<String> titles}) async =>
      [];
  @override
  Future<TaskItem> updateTaskStatus(ServerScopeId serverId,
          {required String taskId, required String status}) async =>
      throw UnimplementedError();
  @override
  Future<void> deleteTask(ServerScopeId serverId,
      {required String taskId}) async {}
  @override
  Future<TaskItem> claimTask(ServerScopeId serverId,
          {required String taskId}) async =>
      throw UnimplementedError();
  @override
  Future<TaskItem> unclaimTask(ServerScopeId serverId,
          {required String taskId}) async =>
      throw UnimplementedError();
  @override
  Future<TaskItem> convertMessageToTask(ServerScopeId serverId,
          {required String messageId}) async =>
      throw UnimplementedError();
}

/// Throws generic UnknownFailure on getTaskByNumber.
class _GenericErrorTasksRepository extends _NotFoundTasksRepository {
  const _GenericErrorTasksRepository();

  @override
  Future<TaskItem> getTaskByNumber(
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  }) async {
    throw const UnknownFailure(message: 'Network error');
  }
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({required this.snapshot});
  final ConversationDetailSnapshot snapshot;

  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      snapshot;

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async =>
      const ConversationMessagePage(
          messages: [], historyLimited: false, hasOlder: false);

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      const ConversationMessagePage(
          messages: [],
          historyLimited: false,
          hasOlder: false,
          hasNewer: false);

  @override
  Future<ConversationMessagePage> loadMessageContext(
    ConversationDetailTarget target, {
    required String messageId,
  }) async =>
      const ConversationMessagePage(
          messages: [],
          historyLimited: false,
          hasOlder: false,
          hasNewer: false);

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async =>
      'attachment-1';

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async =>
      message;

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async =>
      null;

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async =>
      const [];

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}

class _FakeHomeListStore extends HomeListStore {
  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
        channels: const [],
        directMessages: const [],
      );
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Robin',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}

class _FakeChannelMemberRepository implements ChannelMemberRepository {
  const _FakeChannelMemberRepository();

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async =>
      const [];

  @override
  Future<void> addHumanMember(ServerScopeId serverId,
      {required String channelId, required String userId}) async {}

  @override
  Future<void> addAgentMember(ServerScopeId serverId,
      {required String channelId, required String agentId}) async {}

  @override
  Future<void> removeHumanMember(ServerScopeId serverId,
      {required String channelId, required String userId}) async {}

  @override
  Future<void> removeAgentMember(ServerScopeId serverId,
      {required String channelId, required String agentId}) async {}
}

class _FakeProfileRepository implements ProfileRepository {
  const _FakeProfileRepository();

  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) async =>
      const MemberProfile(
        id: 'user-2',
        displayName: 'Sender',
        username: 'sender',
        role: 'member',
        presence: 'online',
      );
}

class _FakeMemberRepository implements MemberRepository {
  const _FakeMemberRepository();

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async =>
      const [];
  @override
  Future<String> createInvite(ServerScopeId serverId) async => 'code';
  @override
  Future<void> updateMemberRole(ServerScopeId serverId,
      {required String userId, required String role}) async {}
  @override
  Future<void> removeMember(ServerScopeId serverId,
      {required String userId}) async {}
  @override
  Future<String> openDirectMessage(ServerScopeId serverId,
          {required String userId}) async =>
      'dm-default';
  @override
  Future<String> openAgentDirectMessage(ServerScopeId serverId,
          {required String agentId}) async =>
      'dm-default';
}

// =============================================================================
// Fakes — Task claim 409 (real TasksPage)
// =============================================================================

/// Fake TasksStore that throws ConflictFailure when claimTask is called.
/// This exercises the real _TasksScreenState._claimTask → on ConflictFailure path.
class _ConflictClaimTasksStore extends TasksStore {
  _ConflictClaimTasksStore({required TasksState initialState})
      : _initialState = initialState;

  final TasksState _initialState;

  @override
  TasksState build() => _initialState;

  @override
  Future<void> load() async {}

  @override
  Future<void> claimTask(String taskId) async {
    throw const ConflictFailure(
      message: 'Task already claimed',
      statusCode: 409,
    );
  }

  @override
  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {}
}

// =============================================================================
// Fakes — Non-member notification (real appRouterProvider)
// =============================================================================

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];
  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

class _StallingSplashController extends SplashController {
  @override
  Future<void> build() => Completer<void>().future;
}

class _FakeServerListRepository implements ServerListRepository {
  _FakeServerListRepository(List<String> serverIds)
      : _servers =
            serverIds.map((id) => ServerSummary(id: id, name: id)).toList();

  final List<ServerSummary> _servers;

  @override
  Future<List<ServerSummary>> loadServers() async => _servers;
}
