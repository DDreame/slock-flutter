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
// #518: Scroll-to-bottom FAB
//
// 3 tests for scroll-to-bottom FAB behavior:
//   INV-FAB-1: offset > 300 from bottom → FAB visible
//   INV-FAB-2: offset <= 300 from bottom → FAB hidden
//   INV-FAB-3: FAB tap → animate to bottom (offset 0)
//
// With reverse:true, offset 0 = bottom (newest messages).
// FAB appears when user scrolls up (offset > 300).
// ---------------------------------------------------------------------------

/// Generate a list of messages large enough to make the list scrollable.
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
    // Use pump() instead of pumpAndSettle() — the TypingIndicatorWidget's
    // _AnimatedDots has a repeating animation that never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  // -----------------------------------------------------------------------
  // 1. Scroll up past 300px → FAB visible (INV-FAB-1)
  //
  // Phase B: _ConversationDetailScreen must wrap the message list in a
  //   Stack and add a scroll-to-bottom FAB (keyed 'scroll-to-bottom-fab')
  //   that appears when scrollController.offset > 300.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: scroll up past 300px shows scroll-to-bottom FAB (INV-FAB-1)',
    (tester) async {
      await pumpScrollableConversation(tester);

      // Initially at bottom (offset ~0) — FAB must not be visible.
      expect(
        find.byKey(const ValueKey('scroll-to-bottom-fab')),
        findsNothing,
        reason: 'FAB must be hidden when at bottom of conversation',
      );

      // Scroll up (positive Y drag in reversed list increases offset).
      // Multiple drags to get past 300px.
      await tester.drag(
        find.byKey(const ValueKey('conversation-success')),
        const Offset(0, 200),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(
        find.byKey(const ValueKey('conversation-success')),
        const Offset(0, 200),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Now offset should be > 300. FAB must be visible.
      expect(
        find.byKey(const ValueKey('scroll-to-bottom-fab')),
        findsOneWidget,
        reason: 'FAB must appear when scrolled more than 300px from bottom '
            '(INV-FAB-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 2. At bottom (offset <= 300) → FAB hidden (INV-FAB-2)
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: at bottom of list FAB is hidden (INV-FAB-2)',
    (tester) async {
      await pumpScrollableConversation(tester);

      // At bottom — FAB must not be visible.
      expect(
        find.byKey(const ValueKey('scroll-to-bottom-fab')),
        findsNothing,
        reason: 'FAB must be hidden when at bottom of conversation '
            '(INV-FAB-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 3. FAB tap → animate to bottom (INV-FAB-3)
  //
  // Phase B: tapping the FAB calls animateTo(0, duration: 300ms) and
  //   hides the FAB after the animation completes.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: FAB tap scrolls to bottom and hides FAB (INV-FAB-3)',
    (tester) async {
      await pumpScrollableConversation(tester);

      // Scroll up past threshold.
      await tester.drag(
        find.byKey(const ValueKey('conversation-success')),
        const Offset(0, 200),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(
        find.byKey(const ValueKey('conversation-success')),
        const Offset(0, 200),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // FAB must be visible.
      final fabFinder = find.byKey(const ValueKey('scroll-to-bottom-fab'));
      expect(fabFinder, findsOneWidget, reason: 'FAB must be visible to tap');

      // Read scroll position before tap — must be > 300.
      final listFinder = find.byKey(const ValueKey('conversation-success'));
      final listWidget = tester.widget<ListView>(listFinder);
      final controller = listWidget.controller!;
      expect(
        controller.position.pixels,
        greaterThan(300),
        reason: 'Scroll offset must be > 300 before FAB tap (INV-FAB-3)',
      );

      // Tap FAB.
      await tester.tap(fabFinder);
      // Pump multiple frames to complete the 300ms scroll animation.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // After animation, scroll position must be back at bottom (~0).
      expect(
        controller.position.pixels,
        closeTo(0.0, 1.0),
        reason: 'FAB tap must animate scroll position back to bottom '
            '(offset 0 in reverse:true) (INV-FAB-3)',
      );

      // After animation, FAB must be hidden (back at bottom).
      expect(
        find.byKey(const ValueKey('scroll-to-bottom-fab')),
        findsNothing,
        reason: 'FAB must hide after tapping and scrolling to bottom '
            '(INV-FAB-3)',
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
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

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
