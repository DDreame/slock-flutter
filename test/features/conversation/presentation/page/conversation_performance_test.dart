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
// #519: Chat Performance Optimization — Phase A (test-only)
//
// 4 tests for performance invariants:
//   INV-PERF-1: updateViewportOffset calls ≤ 10 during 1s of rapid scrolling
//   INV-PERF-2: Each message item wrapped in RepaintBoundary
//   INV-PERF-3: No per-message LayoutBuilder in the message list
//   INV-PERF-4: ListView cacheExtent set to 500
//
// skip: true until Phase B implements performance optimizations.
// ---------------------------------------------------------------------------

/// Generate a list of messages for a scrollable conversation.
List<ConversationMessageSummary> _generateMessages(int count) {
  return List.generate(count, (i) {
    final ts = DateTime.utc(2026, 5, 16, 10, 0).add(Duration(minutes: i));
    return ConversationMessageSummary(
      id: 'msg-$i',
      content: 'Test message number $i with enough text to fill some space.',
      createdAt: ts,
      senderType: 'human',
      senderId: 'user-${i % 3 + 2}',
      senderName: ['Alice', 'Bob', 'Charlie'][i % 3],
      messageType: 'message',
      seq: i + 1,
    );
  });
}

void main() {
  // -----------------------------------------------------------------------
  // Helper: pump ConversationDetailPage with many messages.
  // -----------------------------------------------------------------------
  Future<void> pumpScrollableConversation(WidgetTester tester) async {
    final repo = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-1',
          ),
        ),
        title: '#general',
        messages: _generateMessages(50),
        historyLimited: false,
        hasOlder: false,
      ),
    );

    await tester.pumpWidget(_buildConversationApp(repo));
    await tester.pumpAndSettle();
  }

  // -----------------------------------------------------------------------
  // 1. Scroll throttle — updateViewportOffset ≤ 10 calls/sec (INV-PERF-1)
  //
  // Phase B: _handleScroll must throttle updateViewportOffset with a 100ms
  //   timer so rapid scrolling does not fire 60+ state writes per second.
  //   FAB state updates stay unthrottled.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: updateViewportOffset throttled during rapid scroll '
    '(INV-PERF-1)',
    skip: true,
    (tester) async {
      await pumpScrollableConversation(tester);

      // Perform many rapid drags to simulate fast scrolling (10 drags).
      for (var i = 0; i < 10; i++) {
        await tester.drag(
          find.byKey(const ValueKey('conversation-success')),
          const Offset(0, 50),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      // Phase B must ensure that despite many scroll events, the
      // updateViewportOffset call count stays ≤ 10 per second of scrolling.
      // The throttle timer (100ms debounce) limits the write frequency.
      //
      // Verification approach: after Phase B adds the throttle timer,
      // this test can inspect the session store's saved scroll offset
      // to confirm writes are batched, not per-frame.
      //
      // For now, we verify the conversation list is still functional
      // after rapid scrolling (no exceptions from throttle logic).
      expect(
        find.byKey(const ValueKey('conversation-success')),
        findsOneWidget,
        reason: 'Conversation list must remain stable after rapid scrolling '
            '(INV-PERF-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 2. Each message item wrapped in RepaintBoundary (INV-PERF-2)
  //
  // Phase B: itemBuilder must wrap each _ConversationMessageCard in a
  //   RepaintBoundary so Flutter can cache raster images of individual
  //   messages during scrolling.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: each message card wrapped in RepaintBoundary '
    '(INV-PERF-2)',
    skip: true,
    (tester) async {
      await pumpScrollableConversation(tester);

      // Find a visible message card.
      final msgFinder = find.byKey(const ValueKey('message-msg-49'));
      expect(msgFinder, findsOneWidget, reason: 'Message must be rendered');

      // The message card must have a RepaintBoundary ancestor within the
      // list (not counting the screenshot RepaintBoundary that wraps the
      // entire list).
      final listFinder = find.byKey(const ValueKey('conversation-success'));
      final repaintBoundaries = find.descendant(
        of: listFinder,
        matching: find.byType(RepaintBoundary),
      );

      // With 50 messages, there should be at least one RepaintBoundary
      // per visible message card.
      expect(
        repaintBoundaries,
        findsWidgets,
        reason: 'Message cards must be wrapped in RepaintBoundary '
            '(INV-PERF-2)',
      );

      // Verify by checking a specific message has a RepaintBoundary ancestor
      // between it and the ListView.
      expect(
        find.ancestor(
          of: msgFinder,
          matching: find.descendant(
            of: listFinder,
            matching: find.byType(RepaintBoundary),
          ),
        ),
        findsWidgets,
        reason: 'Each message must have a RepaintBoundary ancestor inside '
            'the list (INV-PERF-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 3. No per-message LayoutBuilder (INV-PERF-3)
  //
  // Phase B: maxBubbleWidth must be computed once at the list level
  //   (MediaQuery.of(context).size.width * fraction) and passed down,
  //   removing the per-message LayoutBuilder that causes unnecessary
  //   layout passes.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: no per-message LayoutBuilder in message list '
    '(INV-PERF-3)',
    skip: true,
    (tester) async {
      await pumpScrollableConversation(tester);

      // Find the message list.
      final listFinder = find.byKey(const ValueKey('conversation-success'));
      expect(listFinder, findsOneWidget);

      // There must be no LayoutBuilder widgets inside the message list.
      // Phase B removes per-message LayoutBuilder and computes
      // maxBubbleWidth once at the list level.
      expect(
        find.descendant(
          of: listFinder,
          matching: find.byType(LayoutBuilder),
        ),
        findsNothing,
        reason: 'No per-message LayoutBuilder should exist inside the '
            'message list — maxBubbleWidth must be computed at list level '
            '(INV-PERF-3)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 4. ListView cacheExtent set to 500 (INV-PERF-4)
  //
  // Phase B: ListView.separated must set cacheExtent: 500 to pre-build
  //   messages beyond the visible viewport, reducing jank during scrolling.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: ListView cacheExtent is 500 (INV-PERF-4)',
    skip: true,
    (tester) async {
      await pumpScrollableConversation(tester);

      final listFinder = find.byKey(const ValueKey('conversation-success'));
      final listWidget = tester.widget<ListView>(listFinder);

      expect(
        listWidget.cacheExtent,
        500,
        reason: 'ListView must have cacheExtent of 500 for pre-building '
            'off-screen messages (INV-PERF-4)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
        displayName: 'TestUser',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}
