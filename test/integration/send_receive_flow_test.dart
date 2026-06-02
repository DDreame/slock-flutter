// =============================================================================
// B132 — Integration Flow Test: Send → Receive
//
// Verifies the send→receive message flow with real ConversationDetailPage:
// 1. Type message in composer → tap send → optimistic pending message appears
// 2. Repository.sendMessage succeeds → message transitions to sent
// 3. Realtime message:new event from another user → new message appears
//
// Load-bearing: reverting optimistic send or realtime append must break test.
// =============================================================================

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  final testTarget = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('srv-1'),
      value: 'ch-1',
    ),
  );

  group('B132 — Send → Receive flow', () {
    testWidgets(
        'type message, tap send, optimistic message appears then confirms',
        (tester) async {
      final connectivityController =
          StreamController<ConnectivityStatus>.broadcast();
      addTearDown(connectivityController.close);
      final connectivityService = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: connectivityController,
      );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = _DelayedSendRepository();

      await tester.pumpWidget(
        _buildConversationApp(
          target: testTarget,
          connectivityService: connectivityService,
          prefs: prefs,
          conversationRepo: repository,
        ),
      );
      await tester.pumpAndSettle();

      // Type a message in the composer.
      final composerInput = find.byKey(const ValueKey('composer-input'));
      expect(composerInput, findsOneWidget);
      await tester.enterText(composerInput, 'Hello world');
      await tester.pump();

      // Tap send.
      final sendButton = find.byKey(const ValueKey('composer-send'));
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pump();

      // Assert: optimistic pending message appears with sending indicator.
      expect(find.text('Hello world'), findsWidgets);
      expect(
        find.byKey(const ValueKey('pending-sending-indicator')),
        findsOneWidget,
        reason: 'Optimistic message must show sending indicator',
      );

      // Complete the send.
      repository.completeSend();
      await tester.pumpAndSettle();

      // Assert: message content still visible (now confirmed), sending
      // indicator gone — proves the pending→confirmed state transition.
      expect(find.text('Hello world'), findsWidgets);
      expect(
        find.byKey(const ValueKey('pending-sending-indicator')),
        findsNothing,
        reason: 'Sending indicator must disappear after send confirms',
      );
    });

    testWidgets('realtime message:new from another user appends to list',
        (tester) async {
      final connectivityController =
          StreamController<ConnectivityStatus>.broadcast();
      addTearDown(connectivityController.close);
      final connectivityService = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: connectivityController,
      );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ingress = RealtimeReductionIngress();
      addTearDown(() => ingress.dispose());

      await tester.pumpWidget(
        _buildConversationApp(
          target: testTarget,
          connectivityService: connectivityService,
          prefs: prefs,
          realtimeIngress: ingress,
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial message is shown.
      expect(find.text('Initial message'), findsOneWidget);

      // Simulate realtime message:new event from another user.
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'channel:ch-1',
        seq: 2,
        receivedAt: DateTime.now(),
        payload: {
          'id': 'msg-2',
          'channelId': 'ch-1',
          'content': 'New realtime message',
          'createdAt': DateTime.now().toIso8601String(),
          'senderId': 'user-3',
          'senderType': 'human',
          'senderName': 'Other User',
          'messageType': 'message',
          'seq': 2,
        },
      ));
      await tester.pump();
      // Allow the async persistMessage + state update to complete.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Assert: new message content appears in the list.
      expect(find.text('New realtime message'), findsOneWidget);
    });
  });
}

// =============================================================================
// Shared widget builder
// =============================================================================

Widget _buildConversationApp({
  required ConversationDetailTarget target,
  required ConnectivityService connectivityService,
  required SharedPreferences prefs,
  ConversationRepository? conversationRepo,
  RealtimeReductionIngress? realtimeIngress,
}) {
  final repo = conversationRepo ?? _DelayedSendRepository();

  final router = GoRouter(
    initialLocation: '/conversation',
    routes: [
      GoRoute(
        path: '/conversation',
        builder: (_, __) => ConversationDetailPage(target: target),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(repo),
      connectivityServiceProvider.overrideWithValue(connectivityService),
      sharedPreferencesProvider.overrideWithValue(prefs),
      channelMemberRepositoryProvider
          .overrideWithValue(const _FakeChannelMemberRepository()),
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      profileRepositoryProvider
          .overrideWithValue(const _FakeProfileRepository()),
      memberRepositoryProvider.overrideWithValue(const _FakeMemberRepository()),
      homeListStoreProvider.overrideWith(() => _FakeHomeListStore()),
      if (realtimeIngress != null)
        realtimeReductionIngressProvider.overrideWithValue(realtimeIngress),
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

class _DelayedSendRepository implements ConversationRepository {
  Completer<void>? _sendCompleter;
  final List<String> sentContents = [];

  void completeSend() {
    _sendCompleter?.complete();
    _sendCompleter = null;
  }

  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      ConversationDetailSnapshot(
        target: target,
        title: '#test-channel',
        messages: [
          ConversationMessageSummary(
            id: 'msg-1',
            content: 'Initial message',
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
      );

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
    String? clientId,
    CancelToken? cancelToken,
  }) async {
    sentContents.add(content);
    _sendCompleter = Completer<void>();
    await _sendCompleter!.future;
    return ConversationMessageSummary(
      id: 'sent-${sentContents.length}',
      content: content,
      createdAt: DateTime.now(),
      senderType: 'human',
      messageType: 'message',
      seq: sentContents.length + 1,
    );
  }

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
