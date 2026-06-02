// =============================================================================
// B132 — Integration Flow Test: Offline → Reconnect
//
// Verifies the offline→reconnect flow with real ConversationDetailPage:
// 1. Offline state shows offline banner
// 2. Connectivity restored hides banner
// 3. Queued outbox message drains on reconnect (pending→sent)
//
// Load-bearing: reverting banner or outbox drain-on-connectivity must break.
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
import 'package:slock_app/features/conversation/application/outbox_store.dart';
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

  group('B132 — Offline → Reconnect flow', () {
    testWidgets(
        'offline banner appears then disappears on connectivity restore',
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
        ),
      );
      await tester.pumpAndSettle();

      // Assert: offline banner is visible.
      expect(
        find.byKey(const ValueKey('offline-banner')),
        findsOneWidget,
        reason: 'Offline banner must appear when connectivity is offline',
      );

      // Act: restore connectivity.
      connectivityController.add(ConnectivityStatus.online);
      await tester.pumpAndSettle();

      // Assert: offline banner disappears.
      expect(
        find.byKey(const ValueKey('offline-banner')),
        findsNothing,
        reason: 'Offline banner must disappear when connectivity is restored',
      );
    });

    testWidgets('outbox queued message drains on connectivity restore',
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

      final repository = _TrackingConversationRepository();

      await tester.pumpWidget(
        _buildConversationApp(
          target: testTarget,
          connectivityService: connectivityService,
          prefs: prefs,
          conversationRepo: repository,
        ),
      );
      await tester.pumpAndSettle();

      // Get the inner container to interact with the outbox.
      final innerElement = tester.element(
        find.byKey(const ValueKey('composer-input')),
      );
      final container = ProviderScope.containerOf(innerElement);

      // Enqueue a message in the outbox while offline.
      final outbox = container.read(outboxStoreProvider.notifier);
      outbox.enqueue(testTarget, 'queued-msg', localId: 'local-1');

      // Verify it's in the outbox.
      final targetKey = outboxTargetKey(testTarget);
      final state = container.read(outboxStoreProvider);
      expect(state.items[targetKey]?.length, 1);

      // Act: restore connectivity — outbox should drain.
      connectivityController.add(ConnectivityStatus.online);
      await tester.pumpAndSettle();
      // Allow async drain cycle.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Assert: outbox drained and message was sent via repository.
      expect(repository.sentContents, contains('queued-msg'));
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
}) {
  final repo = conversationRepo ?? _TrackingConversationRepository();

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

class _TrackingConversationRepository implements ConversationRepository {
  final List<String> sentContents = [];

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
            content: 'Hello world',
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
