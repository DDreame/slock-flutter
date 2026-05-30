// =============================================================================
// B123 PR 3 — Mention tap → profile navigation INTEGRATION tests.
//
// These tests mount a real ConversationDetailPage (which internally builds
// ConversationMessageCard), tap an @mention, and assert navigation fires.
//
// Tests prove:
// 1. Tapping @mention in ConversationMessageCard navigates to profile route.
// 2. Unresolvable mention handle → no navigation, no crash.
// 3. Recognizer disposal fires on rebuild (proves _disposeMentionRecognizers).
//
// Reverting onMentionTap wiring or context.push(route) → tests RED.
// =============================================================================

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
import 'package:slock_app/features/conversation/presentation/widgets/message_content_widget.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  final channelTarget = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  // ---------------------------------------------------------------------------
  // Integration: Mention tap in ConversationMessageCard → profile navigation
  // ---------------------------------------------------------------------------
  group('B123 PR 3 — ConversationMessageCard mention tap integration', () {
    testWidgets(
      'tapping @mention navigates to /servers/{serverId}/profile/{entityId}',
      (tester) async {
        String? navigatedTo;

        final memberRepo = _FakeChannelMemberRepository(members: [
          const ChannelMember(
            id: 'member-1',
            channelId: 'general',
            userId: 'user-alice-123',
            userName: 'Alice',
          ),
        ]);

        await tester.pumpWidget(
          _buildApp(
            target: channelTarget,
            messageContent: 'Hey @Alice check this out!',
            channelMemberRepo: memberRepo,
            onNavigate: (route) => navigatedTo = route,
          ),
        );
        await tester.pumpAndSettle();

        // Find the mention tap target (GestureDetector keyed 'mention-tap-Alice').
        final mentionTap = find.byKey(const ValueKey('mention-tap-Alice'));
        expect(
          mentionTap,
          findsOneWidget,
          reason:
              'Reverting onMentionTap: _onMentionTap wiring → no tap target → RED.',
        );

        await tester.tap(mentionTap);
        await tester.pumpAndSettle();

        expect(
          navigatedTo,
          '/servers/server-1/profile/user-alice-123',
          reason: 'Reverting context.push(route) → no navigation → RED.',
        );
      },
    );

    testWidgets(
      'unresolvable mention handle → no navigation, no crash',
      (tester) async {
        String? navigatedTo;

        // Repository returns members that do NOT include the mentioned name.
        final memberRepo = _FakeChannelMemberRepository(members: [
          const ChannelMember(
            id: 'member-1',
            channelId: 'general',
            userId: 'user-bob-456',
            userName: 'Bob',
          ),
        ]);

        await tester.pumpWidget(
          _buildApp(
            target: channelTarget,
            messageContent: 'Hey @UnknownPerson look at this',
            channelMemberRepo: memberRepo,
            onNavigate: (route) => navigatedTo = route,
          ),
        );
        await tester.pumpAndSettle();

        // Mention should still render as a tappable chip.
        final mentionTap =
            find.byKey(const ValueKey('mention-tap-UnknownPerson'));
        expect(mentionTap, findsOneWidget);

        await tester.tap(mentionTap);
        await tester.pumpAndSettle();

        // No navigation should occur — graceful no-op.
        expect(
          navigatedTo,
          isNull,
          reason:
              'Unresolvable handle must produce no navigation (graceful no-op).',
        );

        // No exceptions thrown.
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // MessageContentWidget recognizer disposal on rebuild/unmount
  // ---------------------------------------------------------------------------
  group('B123 PR 3 — MessageContentWidget recognizer disposal', () {
    testWidgets(
      '_disposeMentionRecognizers fires on rebuild (debugDisposeCount)',
      (tester) async {
        // Reset counters.
        MessageContentWidget.debugBuildCount = 0;
        MessageContentWidget.debugDisposeCount = 0;

        final controller = _ContentController('Hello @Alice world');

        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: _RebuildableMessageContent(controller: controller),
          ),
        ));
        await tester.pumpAndSettle();

        // After first build, disposal was called once (at start of build()
        // to clear any previous frame — on first frame this is a no-op clear).
        final afterFirstBuild = MessageContentWidget.debugDisposeCount;
        expect(
          afterFirstBuild,
          greaterThan(0),
          reason:
              'Reverting _disposeMentionRecognizers() in build() → count stays 0 → RED.',
        );

        // Trigger rebuild with new content.
        controller.update('Now mention @Bob instead');
        await tester.pumpAndSettle();

        // Disposal should fire again on rebuild.
        expect(
          MessageContentWidget.debugDisposeCount,
          greaterThan(afterFirstBuild),
          reason: 'Removing _disposeMentionRecognizers() from build() → count '
              'does not increment on rebuild → RED.',
        );
      },
    );

    testWidgets(
      '_disposeMentionRecognizers fires on widget unmount (dispose)',
      (tester) async {
        MessageContentWidget.debugBuildCount = 0;
        MessageContentWidget.debugDisposeCount = 0;

        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MessageContentWidget(
              message: ConversationMessageSummary(
                id: 'msg-1',
                content: 'Hello @Alice world',
                createdAt: DateTime.parse('2026-05-29T10:00:00Z'),
                senderId: 'user-1',
                senderType: 'human',
                messageType: 'message',
                senderName: 'Test',
                seq: 1,
              ),
              onMentionTap: (_) {},
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final beforeUnmount = MessageContentWidget.debugDisposeCount;

        // Unmount the widget entirely → dispose() fires.
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SizedBox.shrink()),
        ));
        await tester.pumpAndSettle();

        expect(
          MessageContentWidget.debugDisposeCount,
          greaterThan(beforeUnmount),
          reason:
              'Removing _disposeMentionRecognizers() from dispose() → count '
              'does not increment on unmount → RED.',
        );
      },
    );
  });
}

// =============================================================================
// Helpers
// =============================================================================

Widget _buildApp({
  required ConversationDetailTarget target,
  required String messageContent,
  required _FakeChannelMemberRepository channelMemberRepo,
  required void Function(String route) onNavigate,
}) {
  final conversationRepo = _FakeConversationRepository(
    snapshot: ConversationDetailSnapshot(
      target: target,
      title: '#general',
      messages: [
        ConversationMessageSummary(
          id: 'msg-1',
          content: messageContent,
          createdAt: DateTime.parse('2026-05-29T10:00:00Z'),
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
      // Profile route stub — captures navigation for assertion.
      GoRoute(
        path: '/servers/:serverId/profile/:entityId',
        builder: (_, state) {
          final route =
              '/servers/${state.pathParameters['serverId']}/profile/${state.pathParameters['entityId']}';
          // Fire callback synchronously so test can assert.
          onNavigate(route);
          return Scaffold(
            body: Center(child: Text('profile-$route')),
          );
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(conversationRepo),
      channelMemberRepositoryProvider.overrideWithValue(channelMemberRepo),
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
      memberRepositoryProvider.overrideWithValue(_FakeMemberRepository()),
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
// Stateful wrapper for rebuild tests
// =============================================================================

class _ContentController extends ChangeNotifier {
  _ContentController(this._content);
  String _content;
  String get content => _content;
  void update(String newContent) {
    _content = newContent;
    notifyListeners();
  }
}

class _RebuildableMessageContent extends StatefulWidget {
  const _RebuildableMessageContent({required this.controller});
  final _ContentController controller;

  @override
  State<_RebuildableMessageContent> createState() =>
      _RebuildableMessageContentState();
}

class _RebuildableMessageContentState
    extends State<_RebuildableMessageContent> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MessageContentWidget(
      message: ConversationMessageSummary(
        id: 'msg-rebuild',
        content: widget.controller.content,
        createdAt: DateTime.parse('2026-05-29T10:00:00Z'),
        senderId: 'user-1',
        senderType: 'human',
        messageType: 'message',
        senderName: 'Test',
        seq: 1,
      ),
      onMentionTap: (_) {},
    );
  }
}

// =============================================================================
// Fakes
// =============================================================================

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
  _FakeChannelMemberRepository({required this.members});
  final List<ChannelMember> members;

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    return members;
  }

  @override
  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

  @override
  Future<void> addAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}

  @override
  Future<void> removeHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

  @override
  Future<void> removeAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    return const MemberProfile(
      id: 'user-2',
      displayName: 'Sender',
      username: 'sender',
      role: 'member',
      presence: 'online',
    );
  }
}

class _FakeMemberRepository implements MemberRepository {
  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async =>
      const [];

  @override
  Future<String> createInvite(ServerScopeId serverId) async => 'code';

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
  }) async =>
      'dm-default';

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'dm-default';
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
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      );

  @override
  Future<ConversationMessagePage> loadMessageContext(
    ConversationDetailTarget target, {
    required String messageId,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      );

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
