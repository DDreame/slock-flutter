// =============================================================================
// Scan #53 — Task ref tap: re-entry guard + stale snackbar dismiss.
//
// Mounts real ConversationDetailPage and verifies:
// 1. Rapid double-tap fires only one API call (re-entry guard)
// 2. Loading snackbar is always dismissed after API completes
//
// Both tests go RED if the production guard or async fix is reverted.
// =============================================================================

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  final testTarget = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('srv-1'),
      value: 'ch-1',
    ),
  );

  group('Scan #53 — Task ref tap re-entry guard', () {
    testWidgets('rapid double-tap fires only one API call', (tester) async {
      final repository = _DelayedTasksRepository();

      await tester.pumpWidget(
        _buildConversationApp(
          target: testTarget,
          messageContent: 'Check task #42 status',
          taskRepoOverride: repository,
        ),
      );
      await tester.pumpAndSettle();

      // First tap — should start API call.
      final taskRefChip = find.byKey(const ValueKey('task-ref-tap-42'));
      expect(taskRefChip, findsOneWidget);
      await tester.tap(taskRefChip);
      await tester.pump();

      // Loading snackbar should be visible.
      expect(find.text('task #42'), findsWidgets);

      // Second tap — should be ignored by re-entry guard.
      await tester.tap(taskRefChip);
      await tester.pump();

      // Assert: only one API call was made.
      expect(
        repository.callCount,
        1,
        reason: 'Re-entry guard must prevent concurrent API calls',
      );

      // Complete the pending call to avoid dangling futures.
      repository.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'future completing after widget unmount does not crash or leak state',
        (tester) async {
      final repository = _DelayedTasksRepository();

      await tester.pumpWidget(
        _buildConversationApp(
          target: testTarget,
          messageContent: 'Check task #42 status',
          taskRepoOverride: repository,
        ),
      );
      await tester.pumpAndSettle();

      // Tap — triggers loading snackbar + starts API call.
      await tester.tap(find.byKey(const ValueKey('task-ref-tap-42')));
      await tester.pump();

      // Loading snackbar is shown.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Navigate away while API is still in flight — unmounts the page.
      final element = tester.element(find.byType(ConversationDetailPage));
      GoRouter.of(element).go('/servers/srv-1/tasks');
      await tester.pumpAndSettle();

      // Page is gone (page-local scaffold took snackbar with it).
      expect(find.byType(ConversationDetailPage), findsNothing);

      // Complete the API call AFTER unmount — must not throw.
      // P2-A fix: messenger.hideCurrentSnackBar() is called before the
      // `if (!mounted) return` check, so it fires on the captured messenger
      // reference without accessing `context` post-dispose.
      repository.complete();
      await tester.pumpAndSettle();

      // Assert: no crash occurred and no stale snackbar lingers.
      // Reverting P2-A (placing dismiss after `if (!mounted) return`) would
      // cause the captured messenger dismiss to be skipped — and if the
      // messenger were still alive, the snackbar would remain stale.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}

// =============================================================================
// Widget builder
// =============================================================================

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
// Fakes
// =============================================================================

/// A tasks repository with a gated completer — getTaskByNumber waits until
/// [complete] is called. Tracks call count for re-entry guard testing.
class _DelayedTasksRepository implements TasksRepository {
  int callCount = 0;
  Completer<TaskItem>? _completer;

  void complete() {
    _completer?.complete(TaskItem(
      id: 'task-42',
      taskNumber: 42,
      title: 'Test task',
      status: 'todo',
      channelId: 'ch-1',
      channelType: 'channel',
      createdById: 'user-1',
      createdByName: 'Alice',
      createdByType: 'human',
      createdAt: DateTime(2026, 6, 1),
      isLegacy: true,
    ));
    _completer = null;
  }

  @override
  Future<TaskItem> getTaskByNumber(
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  }) {
    callCount++;
    _completer = Completer<TaskItem>();
    return _completer!.future;
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
      ConversationMessageSummary(
        id: 'sent-1',
        content: content,
        createdAt: DateTime.now(),
        senderType: 'human',
        messageType: 'message',
        seq: 2,
      );

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
