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
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #526: Chat Unread Divider — Phase A
//
// Verifies that the conversation message list shows a "New messages" divider
// at the boundary between read and unread messages, positioned correctly,
// and hidden when there are no unread messages.
//
// Invariants:
//   INV-UNREAD-DIV-1: Unread divider visible when conversation has unread msgs
//   INV-UNREAD-DIV-2: Divider between last read and first unread (correct pos)
//   INV-UNREAD-DIV-3: No divider when unreadCount = 0
//
// Phase A — all tests skip:true (no implementation yet).
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-UNREAD-DIV-1: When conversation has unread messages, a "New messages"
  // divider widget is visible in the message list.
  //
  // Setup: 5 messages total, 2 unread (newest 2). The divider widget keyed
  // 'unread-divider' must appear somewhere in the rendered list.
  // -----------------------------------------------------------------------
  testWidgets(
    'Unread divider visible when conversation has unread messages '
    '(INV-UNREAD-DIV-1)',
    skip: true,
    (tester) async {
      // 5 messages: msg-1..msg-5, with 2 unread (msg-4, msg-5).
      // firstUnreadMessageId = 'msg-4'.
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(
          messageCount: 5,
          firstUnreadMessageId: 'msg-4',
        ),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // The unread divider must be rendered.
      expect(
        find.byKey(const ValueKey('unread-divider')),
        findsOneWidget,
        reason: 'Unread divider must be visible when conversation has '
            'unread messages (INV-UNREAD-DIV-1)',
      );

      // The divider should contain "New messages" text or similar label.
      final dividerFinder = find.byKey(const ValueKey('unread-divider'));
      final textInDivider = find.descendant(
        of: dividerFinder,
        matching: find.byType(Text),
      );
      expect(textInDivider, findsAtLeastNWidgets(1),
          reason: 'Unread divider must contain a text label');
    },
  );

  // -----------------------------------------------------------------------
  // INV-UNREAD-DIV-2: The divider appears between the last read message and
  // the first unread message — correct boundary position.
  //
  // Setup: 5 messages (msg-1..msg-5), 2 unread (msg-4, msg-5).
  // The divider must appear between msg-3 (last read) and msg-4 (first
  // unread). We verify by checking vertical ordering of widgets:
  // msg-3 < divider < msg-4 in the scroll direction.
  // -----------------------------------------------------------------------
  testWidgets(
    'Divider positioned between last read and first unread message '
    '(INV-UNREAD-DIV-2)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(
          messageCount: 5,
          firstUnreadMessageId: 'msg-4',
        ),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Divider must exist.
      final dividerFinder = find.byKey(const ValueKey('unread-divider'));
      expect(dividerFinder, findsOneWidget,
          reason: 'Unread divider must be present');

      // msg-3 (last read) must be rendered.
      final msg3Finder = find.byKey(const ValueKey('message-msg-3'));
      expect(msg3Finder, findsOneWidget,
          reason: 'Last read message (msg-3) must be rendered');

      // msg-4 (first unread) must be rendered.
      final msg4Finder = find.byKey(const ValueKey('message-msg-4'));
      expect(msg4Finder, findsOneWidget,
          reason: 'First unread message (msg-4) must be rendered');

      // In a reverse ListView, newer messages appear lower (closer to
      // bottom). The divider should sit between msg-3 and msg-4 in
      // screen coordinates.
      final dividerTop = tester.getTopLeft(dividerFinder).dy;
      final msg3Top = tester.getTopLeft(msg3Finder).dy;
      final msg4Top = tester.getTopLeft(msg4Finder).dy;

      // In reverse list: msg-4 (newer/unread) is below msg-3 (older/read).
      // Divider sits between them, so:
      //   msg3Top < dividerTop < msg4Top  (in reverse list with newest at
      //   bottom, older messages scroll upward).
      // Note: actual ordering depends on reverse ListView layout — the
      // implementation must place the divider so this spatial relationship
      // holds.
      expect(
        dividerTop,
        greaterThan(msg4Top),
        reason: 'Unread divider must appear above first unread message '
            '(msg-4) in reverse list layout — i.e. between read and '
            'unread boundary (INV-UNREAD-DIV-2)',
      );
      expect(
        dividerTop,
        lessThan(msg3Top),
        reason: 'Unread divider must appear below last read message '
            '(msg-3) in reverse list layout (INV-UNREAD-DIV-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-UNREAD-DIV-3: When all messages are read (unreadCount = 0), no
  // divider is shown.
  //
  // Setup: 5 messages, no firstUnreadMessageId — all read.
  // -----------------------------------------------------------------------
  testWidgets(
    'No divider when all messages are read (INV-UNREAD-DIV-3)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(
          messageCount: 5,
          firstUnreadMessageId: null,
        ),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Messages must be rendered (sanity check).
      expect(
        find.byKey(const ValueKey('message-msg-1')),
        findsOneWidget,
        reason: 'Messages must be rendered',
      );

      // Unread divider must NOT be present.
      expect(
        find.byKey(const ValueKey('unread-divider')),
        findsNothing,
        reason: 'Unread divider must not appear when all messages are '
            'read (unreadCount = 0) (INV-UNREAD-DIV-3)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a snapshot with [messageCount] messages (msg-1..msg-N).
///
/// If [firstUnreadMessageId] is provided, the implementation should use it
/// to position the unread divider. Messages are ordered chronologically
/// (msg-1 oldest, msg-N newest).
ConversationDetailSnapshot _makeSnapshot({
  required int messageCount,
  String? firstUnreadMessageId,
}) {
  final messages = List.generate(
    messageCount,
    (i) => ConversationMessageSummary(
      id: 'msg-${i + 1}',
      content: 'Message ${i + 1}',
      createdAt:
          DateTime.parse('2026-05-16T00:00:00Z').add(Duration(minutes: i * 10)),
      senderType: 'human',
      messageType: 'message',
      seq: i + 1,
    ),
  );

  return ConversationDetailSnapshot(
    target: ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'ch-1',
      ),
    ),
    title: '#general',
    messages: messages,
    historyLimited: false,
    hasOlder: false,
  );
}

Widget _buildConversationApp(_FakeConversationRepository repo) {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'ch-1',
    ),
  );

  return ProviderScope(
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
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({required this.snapshot});

  final ConversationDetailSnapshot snapshot;

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
        displayName: 'Alice',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}
