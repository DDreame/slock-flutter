// =============================================================================
// B125 PR 3 — Copy text vs Copy markdown integration test.
//
// Tests prove:
// 1. Long-pressing a message in ConversationMessageCard shows both
//    "Copy text" and "Copy markdown" in the context menu.
// 2. "Copy text" copies plain text (markdown stripped).
// 3. "Copy markdown" copies raw markdown source.
//
// Reverting onCopyMarkdown wiring or stripMarkdown usage → tests RED.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  const markdownContent = '**bold** @alice #general';
  const plainTextContent = 'bold @alice #general';

  group('B125 PR 3 — Copy text vs Copy markdown integration', () {
    testWidgets(
      'long-press shows both Copy text and Copy markdown in menu',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(target: channelTarget, messageContent: markdownContent),
        );
        await tester.pumpAndSettle();

        // Long-press the message shell to open context menu.
        await tester
            .longPress(find.byKey(const ValueKey('message-shell-msg-1')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('ctx-action-copy')),
          findsOneWidget,
          reason: 'Copy text must appear in context menu.',
        );
        expect(
          find.byKey(const ValueKey('ctx-action-copy-markdown')),
          findsOneWidget,
          reason: 'Reverting onCopyMarkdown wiring → action missing → RED.',
        );
      },
    );

    testWidgets(
      'Copy text copies plain text (markdown stripped)',
      (tester) async {
        String? clipboardContent;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map<dynamic, dynamic>;
              clipboardContent = args['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        await tester.pumpWidget(
          _buildApp(target: channelTarget, messageContent: markdownContent),
        );
        await tester.pumpAndSettle();

        await tester
            .longPress(find.byKey(const ValueKey('message-shell-msg-1')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('ctx-action-copy')));
        await tester.pumpAndSettle();

        expect(
          clipboardContent,
          plainTextContent,
          reason:
              'Reverting stripMarkdown in onCopy → raw markdown copied → RED.',
        );
      },
    );

    testWidgets(
      'Copy markdown copies raw content',
      (tester) async {
        String? clipboardContent;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map<dynamic, dynamic>;
              clipboardContent = args['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        await tester.pumpWidget(
          _buildApp(target: channelTarget, messageContent: markdownContent),
        );
        await tester.pumpAndSettle();

        await tester
            .longPress(find.byKey(const ValueKey('message-shell-msg-1')));
        await tester.pumpAndSettle();

        await tester
            .tap(find.byKey(const ValueKey('ctx-action-copy-markdown')));
        await tester.pumpAndSettle();

        expect(
          clipboardContent,
          markdownContent,
          reason: 'Reverting onCopyMarkdown wiring → action missing → RED.',
        );
      },
    );

    testWidgets(
      'Copy text and Copy markdown produce different payloads',
      (tester) async {
        final payloads = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map<dynamic, dynamic>;
              payloads.add(args['text'] as String);
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        await tester.pumpWidget(
          _buildApp(target: channelTarget, messageContent: markdownContent),
        );
        await tester.pumpAndSettle();

        // First: tap Copy text.
        await tester
            .longPress(find.byKey(const ValueKey('message-shell-msg-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('ctx-action-copy')));
        await tester.pumpAndSettle();

        // Second: tap Copy markdown.
        await tester
            .longPress(find.byKey(const ValueKey('message-shell-msg-1')));
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('ctx-action-copy-markdown')));
        await tester.pumpAndSettle();

        expect(payloads, hasLength(2));
        expect(payloads[0], plainTextContent,
            reason: 'Copy text must strip markdown.');
        expect(payloads[1], markdownContent,
            reason: 'Copy markdown must preserve raw content.');
        expect(payloads[0], isNot(equals(payloads[1])),
            reason:
                'The two actions must produce different clipboard payloads.');
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
    ],
  );

  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(conversationRepo),
      channelMemberRepositoryProvider
          .overrideWithValue(_FakeChannelMemberRepository()),
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
  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async =>
      const [];

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
    String? clientId,
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
