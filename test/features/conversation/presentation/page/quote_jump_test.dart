import 'dart:async';

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
// #531: Quote Jump — Phase A
//
// Verifies that tapping a quoted message block (reply-to) scrolls the
// message list to the original message and provides visual feedback.
//
// The production seam is _QuotedMessageBlock.onTap → onScrollToMessage →
// _scrollToMessageId, which uses proportional offset estimation.
//
// Invariants:
//   INV-QUOTE-JUMP-1: Tap quoted block → scrolls to original message +
//                      shows highlight flash
//   INV-QUOTE-JUMP-2: Quoted message not in loaded window → triggers load
//                      or shows feedback (not silent fallback)
//   INV-QUOTE-JUMP-3: After quote-jump, normal scrolling still works
//
// Phase A:
//   INV-QUOTE-JUMP-1: skip:true for highlight flash (scroll exists but
//                      no visual highlight animation after jump)
//   INV-QUOTE-JUMP-2: skip:true (out-of-window silently falls back to
//                      bottom with no load or feedback)
//   INV-QUOTE-JUMP-3: active (basic scrolling continues working)
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-QUOTE-JUMP-1: Tapping the quoted block scrolls the list toward
  // the original message AND shows a highlight flash on the target.
  //
  // Setup: 5 messages, msg-5 replies to msg-1. Tap the quoted block
  // inside msg-5. After scrolling, msg-1 should have a highlight
  // decoration (keyed 'quote-jump-highlight').
  //
  // The scroll itself already works (proportional estimate). The GAP is
  // the highlight flash — no post-scroll visual feedback exists.
  //
  // skip:true — highlight flash not implemented.
  // -----------------------------------------------------------------------
  testWidgets(
    'Tap quoted block scrolls to original and shows highlight '
    '(INV-QUOTE-JUMP-1)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshotWithReply(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // msg-5 has a quoted block referencing msg-1.
      final quotedBlock = find.byKey(const ValueKey('quoted-msg-5'));
      expect(quotedBlock, findsOneWidget,
          reason: 'Quoted block must be rendered in msg-5');

      // Tap the quoted block.
      await tester.tap(quotedBlock);
      await tester.pumpAndSettle();

      // After scrolling, msg-1 should have a highlight decoration.
      final highlightOnTarget = find.descendant(
        of: find.byKey(const ValueKey('message-shell-msg-1')),
        matching: find.byKey(const ValueKey('quote-jump-highlight')),
      );
      expect(
        highlightOnTarget,
        findsOneWidget,
        reason: 'Original message (msg-1) must show highlight flash '
            'after quote-jump (INV-QUOTE-JUMP-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-QUOTE-JUMP-2: When the quoted message is NOT in the loaded
  // message window, the system should either load the target message
  // page or show feedback — NOT silently scroll to the bottom.
  //
  // Setup: 3 loaded messages (msg-3, msg-4, msg-5). msg-5 replies to
  // msg-1 which is NOT loaded. hasOlder=true.
  //
  // After tap: either msg-1 is loaded and visible, or a loading
  // indicator / snackbar appears. The scroll position should NOT be
  // at offset 0 (bottom/newest).
  //
  // skip:true — currently silently falls back to jumpTo(0).
  // -----------------------------------------------------------------------
  testWidgets(
    'Quoted message not loaded triggers load or feedback '
    '(INV-QUOTE-JUMP-2)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshotMissingTarget(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // msg-5 has a quoted block referencing msg-1 (not loaded).
      final quotedBlock = find.byKey(const ValueKey('quoted-msg-5'));
      expect(quotedBlock, findsOneWidget,
          reason: 'Quoted block must be rendered');

      // Tap the quoted block.
      await tester.tap(quotedBlock);
      await tester.pumpAndSettle();

      // At minimum: either the target message is now visible, or there
      // is a loading indicator / "not found" feedback.
      final targetVisible = find.byKey(const ValueKey('message-shell-msg-1'));
      final loadingVisible = find.byKey(const ValueKey('quote-jump-loading'));
      final notFoundVisible =
          find.byKey(const ValueKey('quote-jump-not-found'));

      expect(
        targetVisible.evaluate().isNotEmpty ||
            loadingVisible.evaluate().isNotEmpty ||
            notFoundVisible.evaluate().isNotEmpty,
        isTrue,
        reason: 'After tapping quoted block for out-of-window message, '
            'either the target message is loaded or a feedback widget '
            'appears (INV-QUOTE-JUMP-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-QUOTE-JUMP-3: After a quote-jump, normal scrolling continues
  // to work (the scroll controller is not in a broken state).
  //
  // Setup: 5 messages with reply. Record scroll offset before tap,
  // tap quoted block to jump (offset changes), then perform a drag
  // gesture to prove the Scrollable still responds post-jump.
  //
  // Active — basic scrolling should continue working after jumpTo.
  // -----------------------------------------------------------------------
  testWidgets(
    'Normal scrolling works after quote-jump (INV-QUOTE-JUMP-3)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshotWithReply(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Find the scrollable list.
      final scrollable = find.byType(Scrollable).first;

      // Record scroll offset before quote-jump.
      final scrollPosition = tester.state<ScrollableState>(scrollable).position;
      final offsetBeforeTap = scrollPosition.pixels;

      // Tap quoted block to trigger a jump.
      final quotedBlock = find.byKey(const ValueKey('quoted-msg-5'));
      expect(quotedBlock, findsOneWidget);
      await tester.tap(quotedBlock);
      await tester.pumpAndSettle();

      // Scroll offset must have changed after the quote-jump.
      final offsetAfterTap = scrollPosition.pixels;
      expect(
        offsetAfterTap,
        isNot(equals(offsetBeforeTap)),
        reason: 'Scroll offset must change after tapping quoted block '
            '(proving the jump happened) (INV-QUOTE-JUMP-3)',
      );

      // Perform a drag gesture to prove scrolling still works post-jump.
      await tester.drag(scrollable, const Offset(0, -100));
      await tester.pumpAndSettle();

      final offsetAfterDrag = scrollPosition.pixels;
      expect(
        offsetAfterDrag,
        isNot(equals(offsetAfterTap)),
        reason: 'Scroll offset must change after drag gesture post-jump, '
            'proving the Scrollable still responds (INV-QUOTE-JUMP-3)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-QUOTE-JUMP-TEMPORAL: The loading spinner must appear BEFORE the
  // fetch completes, and notFound must appear only AFTER the fetch fails.
  //
  // This pins the temporal contract from #649: users see a spinner during
  // the async fetch, and "Message not available" only after load finishes
  // without finding the target. A regression to "immediate error flash"
  // will break this test.
  // -----------------------------------------------------------------------
  testWidgets(
    'Quote-jump shows loading during fetch, notFound only after '
    '(INV-QUOTE-JUMP-TEMPORAL)',
    (tester) async {
      final loadCompleter = Completer<ConversationMessagePage>();
      final repo = _DelayedLoadFakeRepository(
        snapshot: _makeSnapshotMissingTarget(),
        loadOlderCompleter: loadCompleter,
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // msg-5 has a quoted block referencing msg-1 (not loaded).
      final quotedBlock = find.byKey(const ValueKey('quoted-msg-5'));
      expect(quotedBlock, findsOneWidget);

      // Tap the quoted block to trigger _handleQuoteJumpMissing.
      await tester.tap(quotedBlock);

      // Pump a single frame — the setState for loading has fired, but
      // loadOlder is still pending (gated by Completer).
      await tester.pump();

      // ASSERT: loading indicator must be visible.
      expect(
        find.byKey(const ValueKey('quote-jump-loading')),
        findsOneWidget,
        reason: 'Loading spinner must appear while fetch is in-flight '
            '(INV-QUOTE-JUMP-TEMPORAL)',
      );
      // ASSERT: "not found" must NOT be visible yet.
      expect(
        find.byKey(const ValueKey('quote-jump-not-found')),
        findsNothing,
        reason: 'Not-found must not appear before fetch completes '
            '(INV-QUOTE-JUMP-TEMPORAL)',
      );

      // Complete the fetch — returns empty (target not found).
      loadCompleter.complete(const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      ));
      await tester.pumpAndSettle();

      // ASSERT: loading gone, notFound visible.
      expect(
        find.byKey(const ValueKey('quote-jump-loading')),
        findsNothing,
        reason: 'Loading spinner must disappear after fetch completes '
            '(INV-QUOTE-JUMP-TEMPORAL)',
      );
      expect(
        find.byKey(const ValueKey('quote-jump-not-found')),
        findsOneWidget,
        reason: 'Not-found must appear after fetch completes without '
            'finding the target (INV-QUOTE-JUMP-TEMPORAL)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a snapshot with 5 messages where msg-5 replies to msg-1.
ConversationDetailSnapshot _makeSnapshotWithReply() {
  return ConversationDetailSnapshot(
    target: ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'ch-1',
      ),
    ),
    title: '#general',
    messages: [
      ConversationMessageSummary(
        id: 'msg-1',
        content: 'Original message here',
        createdAt: DateTime.parse('2026-05-16T14:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
      ConversationMessageSummary(
        id: 'msg-2',
        content: 'Second message',
        createdAt: DateTime.parse('2026-05-16T14:10:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 2,
      ),
      ConversationMessageSummary(
        id: 'msg-3',
        content: 'Third message',
        createdAt: DateTime.parse('2026-05-16T14:20:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 3,
      ),
      ConversationMessageSummary(
        id: 'msg-4',
        content: 'Fourth message',
        createdAt: DateTime.parse('2026-05-16T14:30:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 4,
      ),
      ConversationMessageSummary(
        id: 'msg-5',
        content: 'Replying to original',
        createdAt: DateTime.parse('2026-05-16T14:40:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 5,
        replyTo: const ReplyToSummary(
          id: 'msg-1',
          content: 'Original message here',
          senderName: 'Alice',
          senderType: 'human',
        ),
      ),
    ],
    historyLimited: false,
    hasOlder: false,
  );
}

/// Creates a snapshot where the reply target (msg-1) is NOT loaded.
/// Only msg-3, msg-4, msg-5 are present. hasOlder=true.
ConversationDetailSnapshot _makeSnapshotMissingTarget() {
  return ConversationDetailSnapshot(
    target: ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'ch-1',
      ),
    ),
    title: '#general',
    messages: [
      ConversationMessageSummary(
        id: 'msg-3',
        content: 'Third message',
        createdAt: DateTime.parse('2026-05-16T14:20:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 3,
      ),
      ConversationMessageSummary(
        id: 'msg-4',
        content: 'Fourth message',
        createdAt: DateTime.parse('2026-05-16T14:30:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 4,
      ),
      ConversationMessageSummary(
        id: 'msg-5',
        content: 'Replying to original',
        createdAt: DateTime.parse('2026-05-16T14:40:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 5,
        replyTo: const ReplyToSummary(
          id: 'msg-1',
          content: 'Original message here',
          senderName: 'Alice',
          senderType: 'human',
        ),
      ),
    ],
    historyLimited: false,
    hasOlder: true,
  );
}

Widget _buildConversationApp(ConversationRepository repo) {
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

/// A variant of [_FakeConversationRepository] where [loadOlderMessages]
/// is gated by a [Completer], allowing tests to assert the loading state
/// before the fetch resolves.
class _DelayedLoadFakeRepository implements ConversationRepository {
  _DelayedLoadFakeRepository({
    required this.snapshot,
    required this.loadOlderCompleter,
  });

  final ConversationDetailSnapshot snapshot;
  final Completer<ConversationMessagePage> loadOlderCompleter;

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
  }) {
    return loadOlderCompleter.future;
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
