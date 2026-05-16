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
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
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
// The unread state is wired through unreadSourceProjectionProvider — the
// production seam that ConversationDetailPage already reads to determine
// whether the conversation has unread messages.
//
// Invariants:
//   INV-UNREAD-DIV-1: Unread divider visible when conversation has unread msgs
//   INV-UNREAD-DIV-2: Divider between last read and first unread (correct pos)
//   INV-UNREAD-DIV-3: No divider when unreadCount = 0
//
// Phase A — all tests skip:true (no implementation yet).
// Phase B — all tests un-skipped (implementation complete).
// ---------------------------------------------------------------------------

/// Channel scope ID used across all tests.
const _channelScopeId = ChannelScopeId(
  serverId: ServerScopeId('server-1'),
  value: 'ch-1',
);

void main() {
  // -----------------------------------------------------------------------
  // INV-UNREAD-DIV-1: When conversation has unread messages, a "New messages"
  // divider widget is visible in the message list.
  //
  // Setup: 5 messages total, unreadCount=2 (newest 2 are unread).
  // The divider widget keyed 'unread-divider' must appear.
  // -----------------------------------------------------------------------
  testWidgets(
    'Unread divider visible when conversation has unread messages '
    '(INV-UNREAD-DIV-1)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(messageCount: 5),
      );

      await tester.pumpWidget(
        _buildConversationApp(repo, unreadCount: 2),
      );
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
  // Setup: 5 messages (msg-1..msg-5), unreadCount=2 (msg-4, msg-5 unread).
  // The divider must appear between msg-3 (last read) and msg-4 (first
  // unread).
  //
  // In a reverse ListView (newest at bottom), screen y-coordinates are:
  //   msg-1.dy < msg-2.dy < msg-3.dy < DIVIDER.dy < msg-4.dy < msg-5.dy
  // -----------------------------------------------------------------------
  testWidgets(
    'Divider positioned between last read and first unread message '
    '(INV-UNREAD-DIV-2)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(messageCount: 5),
      );

      await tester.pumpWidget(
        _buildConversationApp(repo, unreadCount: 2),
      );
      await tester.pumpAndSettle();

      // Divider must exist.
      final dividerFinder = find.byKey(const ValueKey('unread-divider'));
      expect(dividerFinder, findsOneWidget,
          reason: 'Unread divider must be present');

      // msg-3 (last read) must be rendered.
      final msg3Finder = find.byKey(const ValueKey('repaint-boundary-msg-3'));
      expect(msg3Finder, findsOneWidget,
          reason: 'Last read message (msg-3) must be rendered');

      // msg-4 (first unread) must be rendered.
      final msg4Finder = find.byKey(const ValueKey('repaint-boundary-msg-4'));
      expect(msg4Finder, findsOneWidget,
          reason: 'First unread message (msg-4) must be rendered');

      // Spatial ordering check.
      // In reverse ListView: older messages at top (small dy),
      // newer messages at bottom (large dy).
      // msg-3 (older/read) is above msg-4 (newer/unread).
      // Divider sits between: msg3.dy < divider.dy < msg4.dy
      final dividerTop = tester.getTopLeft(dividerFinder).dy;
      final msg3Top = tester.getTopLeft(msg3Finder).dy;
      final msg4Top = tester.getTopLeft(msg4Finder).dy;

      expect(
        dividerTop,
        greaterThan(msg3Top),
        reason: 'Unread divider must be below last read message '
            '(msg-3) — divider.dy > msg-3.dy in reverse list '
            '(INV-UNREAD-DIV-2)',
      );
      expect(
        dividerTop,
        lessThan(msg4Top),
        reason: 'Unread divider must be above first unread message '
            '(msg-4) — divider.dy < msg-4.dy in reverse list '
            '(INV-UNREAD-DIV-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-UNREAD-DIV-3: When all messages are read (unreadCount = 0), no
  // divider is shown.
  //
  // Setup: 5 messages, unreadCount=0 — all read.
  // -----------------------------------------------------------------------
  testWidgets(
    'No divider when all messages are read (INV-UNREAD-DIV-3)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(messageCount: 5),
      );

      await tester.pumpWidget(
        _buildConversationApp(repo, unreadCount: 0),
      );
      await tester.pumpAndSettle();

      // Messages must be rendered (sanity check).
      expect(
        find.byKey(const ValueKey('repaint-boundary-msg-1')),
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
/// Messages are ordered chronologically (msg-1 oldest, msg-N newest).
ConversationDetailSnapshot _makeSnapshot({
  required int messageCount,
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
    target: ConversationDetailTarget.channel(_channelScopeId),
    title: '#general',
    messages: messages,
    historyLimited: false,
    hasOlder: false,
  );
}

/// Builds the app with a conversation page and the unread projection
/// seam overridden to provide [unreadCount] for the test channel.
Widget _buildConversationApp(
  _FakeConversationRepository repo, {
  required int unreadCount,
}) {
  final target = ConversationDetailTarget.channel(_channelScopeId);

  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(repo),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      // Wire the unread state through the production seam.
      unreadSourceProjectionProvider.overrideWithValue(
        UnreadSourceProjectionState(
          channelUnreadCounts: {
            if (unreadCount > 0) _channelScopeId: unreadCount,
          },
          isLoaded: true,
        ),
      ),
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
