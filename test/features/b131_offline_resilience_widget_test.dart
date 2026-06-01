// =============================================================================
// B131 — Offline Resilience: Widget-level proof tests.
//
// Mounts real ConversationDetailPage and verifies:
// 1. Offline attachment snackbar renders on send with offline + attachments
// 2. OutboxFailedBanner renders when outbox has failed items
//
// Both tests go RED if the production UI branches are reverted.
// =============================================================================

import 'dart:async';
import 'dart:convert';

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
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
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

  // ===========================================================================
  // 1. Offline attachment snackbar (real ConversationDetailPage)
  //
  // Mounts the real ConversationDetailPage with connectivity=offline.
  // Types a message, adds a pending attachment, taps send. The real send()
  // method detects offline + attachments and sets sendFailure(causeType:
  // 'offlineAttachment'). The real _handleSend shows the snackbar.
  // Reverting either the store early-return or the page snackbar makes RED.
  // ===========================================================================
  group('B131 — Offline attachment snackbar (real ConversationDetailPage)', () {
    testWidgets('shows snackbar when sending attachment offline',
        (tester) async {
      final connectivityController =
          StreamController<ConnectivityStatus>.broadcast();
      addTearDown(connectivityController.close);
      final connectivityService = ConnectivityService.withInitialStatus(
        ConnectivityStatus.offline,
        controller: connectivityController,
      );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _buildConversationApp(
          target: testTarget,
          connectivityService: connectivityService,
          prefs: prefs,
          // Provide a message so page renders in success state
          messageContent: 'Hello world',
        ),
      );
      await tester.pumpAndSettle();

      // Type something in the composer so canSend is true.
      final composerField = find.byKey(const ValueKey('composer-input'));
      expect(composerField, findsOneWidget);
      await tester.enterText(composerField, 'offline msg');
      await tester.pump();

      // Add a pending attachment via the store directly.
      // The real ConversationDetailStore is built by ProviderScope.
      // We simulate attachment by reading the store and adding one.
      final scope = tester.element(find.byType(ConversationDetailPage));
      final container = ProviderScope.containerOf(scope);
      container
          .read(conversationDetailStoreProvider.notifier)
          .addPendingAttachment(
            const PendingAttachment(
              path: '/tmp/test.png',
              name: 'test.png',
              mimeType: 'image/png',
            ),
          );
      await tester.pump();

      // Tap send
      final sendButton = find.byKey(const ValueKey('composer-send'));
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // The snackbar should appear with the correct key.
      expect(
        find.byKey(const ValueKey('offline-attachment-snackbar')),
        findsOneWidget,
      );
    });
  });

  // ===========================================================================
  // 2. OutboxFailedBanner (real ConversationDetailPage)
  //
  // Pre-seeds outbox SharedPreferences with a failed item for the test target.
  // Mounts the real ConversationDetailPage. The real _OutboxFailedBanner
  // watches outboxStoreProvider and renders the banner. Reverting the widget
  // makes this test RED.
  // ===========================================================================
  group('B131 — Outbox failed banner (real ConversationDetailPage)', () {
    testWidgets('shows failed-message banner when outbox has failed items',
        (tester) async {
      final connectivityController =
          StreamController<ConnectivityStatus>.broadcast();
      addTearDown(connectivityController.close);
      final connectivityService = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: connectivityController,
      );

      // Pre-seed outbox with a failed item for our target.
      final targetKey = outboxTargetKey(testTarget);
      final outboxData = {
        targetKey: [
          {
            'localId': 'failed-1',
            'content': 'This message failed',
            'createdAt': DateTime(2026, 6, 1).toIso8601String(),
            'status': 'failed',
            'failureMessage': 'Server unreachable',
            'retryCount': 5,
          },
        ],
      };
      SharedPreferences.setMockInitialValues({
        'outbox_queue': jsonEncode(outboxData),
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _buildConversationApp(
          target: testTarget,
          connectivityService: connectivityService,
          prefs: prefs,
          messageContent: 'Hello world',
        ),
      );
      await tester.pumpAndSettle();

      // The banner should be visible.
      expect(
        find.byKey(const ValueKey('outbox-failed-banner')),
        findsOneWidget,
      );

      // Verify it shows the failed count text.
      expect(find.text('1 message failed to send'), findsOneWidget);

      // Verify the retry button is present.
      expect(
        find.byKey(const ValueKey('outbox-failed-retry-button')),
        findsOneWidget,
      );
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
  required String messageContent,
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
    ],
  );

  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(conversationRepo),
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
