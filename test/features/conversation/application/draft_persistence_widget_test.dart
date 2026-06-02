// =============================================================================
// Message Draft Persistence — Widget Integration Test
//
// Verifies:
// 1. Type text in composer → navigate away → return → draft restored
// 2. Send message → draft cleared (not restored on return)
// 3. Pending attachment survives conversation switch
//
// Load-bearing: reverting _persistSession in ref.onDispose or session entry
// attachment persistence must break these tests.
// =============================================================================

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
  final target1 = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('srv-1'),
      value: 'ch-1',
    ),
  );
  final target2 = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('srv-1'),
      value: 'ch-2',
    ),
  );

  group('Draft persistence — widget flow', () {
    testWidgets('draft text survives conversation switch', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final router = GoRouter(
        initialLocation: '/conversation/ch-1',
        routes: [
          GoRoute(
            path: '/conversation/ch-1',
            builder: (_, __) => ConversationDetailPage(target: target1),
          ),
          GoRoute(
            path: '/conversation/ch-2',
            builder: (_, __) => ConversationDetailPage(target: target2),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildApp(router: router, prefs: prefs),
      );
      await tester.pumpAndSettle();

      // Type a draft message in ch-1.
      final composerInput = find.byKey(const ValueKey('composer-input'));
      expect(composerInput, findsOneWidget);
      await tester.enterText(composerInput, 'My draft message');
      await tester.pump();

      // Navigate to ch-2 (different conversation).
      router.go('/conversation/ch-2');
      await tester.pumpAndSettle();

      // Navigate back to ch-1.
      router.go('/conversation/ch-1');
      await tester.pumpAndSettle();

      // Assert: draft text is restored in the composer.
      final restoredInput = find.byKey(const ValueKey('composer-input'));
      expect(restoredInput, findsOneWidget);
      final controller = (tester.widget<TextField>(restoredInput).controller)!;
      expect(
        controller.text,
        'My draft message',
        reason: 'Draft text must be restored after conversation switch',
      );
    });

    testWidgets('send clears draft (not restored on return)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final router = GoRouter(
        initialLocation: '/conversation/ch-1',
        routes: [
          GoRoute(
            path: '/conversation/ch-1',
            builder: (_, __) => ConversationDetailPage(target: target1),
          ),
          GoRoute(
            path: '/conversation/ch-2',
            builder: (_, __) => ConversationDetailPage(target: target2),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildApp(router: router, prefs: prefs),
      );
      await tester.pumpAndSettle();

      // Type and send.
      final composerInput = find.byKey(const ValueKey('composer-input'));
      await tester.enterText(composerInput, 'Sent message');
      await tester.pump();

      final sendButton = find.byKey(const ValueKey('composer-send'));
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Navigate away and back.
      router.go('/conversation/ch-2');
      await tester.pumpAndSettle();
      router.go('/conversation/ch-1');
      await tester.pumpAndSettle();

      // Assert: draft is empty (was cleared on send).
      final restoredInput = find.byKey(const ValueKey('composer-input'));
      final controller = (tester.widget<TextField>(restoredInput).controller)!;
      expect(
        controller.text,
        '',
        reason: 'Draft must be empty after successful send',
      );
    });

    testWidgets('pending attachment survives conversation switch',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final router = GoRouter(
        initialLocation: '/conversation/ch-1',
        routes: [
          GoRoute(
            path: '/conversation/ch-1',
            builder: (_, __) => ConversationDetailPage(target: target1),
          ),
          GoRoute(
            path: '/conversation/ch-2',
            builder: (_, __) => ConversationDetailPage(target: target2),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildApp(router: router, prefs: prefs),
      );
      await tester.pumpAndSettle();

      // Inject a pending attachment into the store (mimics file picker).
      final composerElement =
          tester.element(find.byKey(const ValueKey('composer-input')));
      final container = ProviderScope.containerOf(composerElement);
      final store = container.read(conversationDetailStoreProvider.notifier);
      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/test-photo.jpg',
        name: 'test-photo.jpg',
        mimeType: 'image/jpeg',
      ));
      await tester.pumpAndSettle();

      // Verify attachment chip is visible.
      expect(
        find.byKey(const ValueKey('pending-attachment-0')),
        findsOneWidget,
        reason: 'Pending attachment chip must be visible after add',
      );

      // Navigate to ch-2 (disposes ch-1 store).
      router.go('/conversation/ch-2');
      await tester.pumpAndSettle();

      // Navigate back to ch-1 (restores from session).
      router.go('/conversation/ch-1');
      await tester.pumpAndSettle();

      // Assert: pending attachment is restored.
      expect(
        find.byKey(const ValueKey('pending-attachment-0')),
        findsOneWidget,
        reason: 'Pending attachment must survive conversation switch '
            '(reverting session entry attachment persistence breaks this)',
      );
    });
  });
}

// =============================================================================
// Widget builder
// =============================================================================

Widget _buildApp({
  required GoRouter router,
  required SharedPreferences prefs,
}) {
  return ProviderScope(
    overrides: [
      conversationRepositoryProvider
          .overrideWithValue(_FakeConversationRepository()),
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
        title: '#${target.conversationId}',
        messages: [
          ConversationMessageSummary(
            id: 'msg-1-${target.conversationId}',
            content: 'Hello from ${target.conversationId}',
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
