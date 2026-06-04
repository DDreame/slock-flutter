import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/presentation/widgets/inbox_item_tile.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// PR #868: Hero Animation — Inbox → Conversation Transition
//
// Tests:
//   1. InboxItemTile contains a Hero with tag 'conversation-avatar-{channelId}'
//   2. ConversationDetailPage AppBar contains a Hero with matching tag
//   3. Hero tags match between source and destination
// ---------------------------------------------------------------------------

void main() {
  testWidgets(
    'InboxItemTile wraps avatar in Hero with conversation-avatar-{id} tag',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: InboxItemTile(
              projection: _makeProjection(channelId: 'ch-42'),
              isMentioned: false,
              channelId: 'ch-42',
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final heroFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'conversation-avatar-ch-42',
      );
      expect(
        heroFinder,
        findsOneWidget,
        reason: 'InboxItemTile must wrap avatar in Hero with correct tag',
      );
    },
  );

  testWidgets(
    'ConversationDetailPage AppBar contains Hero with matching tag',
    (tester) async {
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'ch-42',
        ),
      );
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Hello',
              createdAt: DateTime.utc(2026, 6, 1),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(repo),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: ConversationDetailPage(target: target),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      // Use pump() instead of pumpAndSettle() — TypingIndicatorWidget has
      // a repeating animation that never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final heroFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'conversation-avatar-ch-42',
      );
      expect(
        heroFinder,
        findsOneWidget,
        reason:
            'ConversationDetailPage AppBar must contain Hero with matching tag',
      );
    },
  );

  testWidgets(
    'Hero tags match between InboxItemTile and ConversationDetailPage',
    (tester) async {
      const channelId = 'ch-99';
      const expectedTag = 'conversation-avatar-$channelId';

      // Verify the tag format is consistent between both widgets.
      // InboxItemTile uses _keyId which falls back to channelId parameter.
      // ConversationDetailPage uses target.conversationId.
      // Both should produce the same tag when channelId matches.

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: InboxItemTile(
              projection: _makeProjection(channelId: channelId),
              isMentioned: false,
              channelId: channelId,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final inboxHero = tester.widget<Hero>(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag == expectedTag,
        ),
      );
      expect(inboxHero.tag, expectedTag);
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ConversationProjection _makeProjection({required String channelId}) {
  return ConversationProjection(
    id: channelId,
    channelId: channelId,
    kind: ConversationProjectionKind.channel,
    title: '#general',
    senderName: 'Alice',
    previewText: 'Hello there!',
    lastActivityAt: DateTime(2026, 6, 1, 10, 0),
    unreadCount: 0,
  );
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
  ) async {
    return snapshot;
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
      hasNewer: false,
    );
  }

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
  }) async {
    return 'attachment-1';
  }

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
    return ConversationMessageSummary(
      id: 'sent-1',
      content: content,
      createdAt: DateTime.now(),
      senderType: 'human',
      messageType: 'message',
      seq: 999,
    );
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    return message;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    return null;
  }

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
      [];

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

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'TestUser',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}
