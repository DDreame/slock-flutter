import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_list.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #519: Chat Performance Optimization
//
// 4 tests for performance invariants:
//   INV-PERF-1: updateViewportOffset calls ≤ 10 during 1s of rapid scrolling
//   INV-PERF-2: Each message item wrapped in RepaintBoundary
//   INV-PERF-3: No per-message LayoutBuilder in the message list
//   INV-PERF-4: ListView cacheExtent set to 500
//
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
    (tester) async {
      final sessionSpy = _CountingSessionCache();
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

      await tester.pumpWidget(
        _buildConversationAppWithSessionSpy(repo, sessionSpy),
      );
      await tester.pumpAndSettle();

      // Reset counter after initial load (which may trigger writes).
      sessionSpy.saveScrollOffsetCount = 0;

      // Perform many rapid drags to simulate fast scrolling (20 drags,
      // each 16ms apart ≈ 60fps for ~320ms of scrolling).
      for (var i = 0; i < 20; i++) {
        await tester.drag(
          find.byKey(const ValueKey('conversation-success')),
          const Offset(0, 30),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      // With a 100ms throttle, 320ms of scrolling should produce at most
      // ~4 writes (320/100 + 1 trailing). Allow ≤ 10 for safety margin.
      // Without throttle, every scroll event fires a write (20+).
      expect(
        sessionSpy.saveScrollOffsetCount,
        lessThanOrEqualTo(10),
        reason: 'updateViewportOffset must be throttled to ≤ 10 writes '
            'during rapid scrolling, not 20+ per-frame writes '
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
    (tester) async {
      await pumpScrollableConversation(tester);

      // Check a specific visible message card (index 49 = newest, at bottom
      // with reverse:true so it renders first).
      final msgFinder = find.byKey(const ValueKey('message-msg-49'));
      expect(msgFinder, findsOneWidget, reason: 'Message must be rendered');

      // Walk up from the message card. The immediate wrapper inside the
      // ListView must be a RepaintBoundary keyed per message item.
      // This must NOT be the screenshot RepaintBoundary that wraps the
      // entire list (which already exists at the Stack level).
      //
      // Phase B wraps each _ConversationMessageCard return in itemBuilder
      // with RepaintBoundary(key: ValueKey('repaint-boundary-${msg.id}')).
      expect(
        find.byKey(const ValueKey('repaint-boundary-msg-49')),
        findsOneWidget,
        reason: 'Each message must have its own keyed RepaintBoundary '
            'wrapper (INV-PERF-2)',
      );

      // Verify the message card is a descendant of its per-item boundary.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('repaint-boundary-msg-49')),
          matching: msgFinder,
        ),
        findsOneWidget,
        reason: 'Message card must be inside its own per-item '
            'RepaintBoundary (INV-PERF-2)',
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

  // -----------------------------------------------------------------------
  // 5. MediaQuery.sizeOf suppresses rebuild on keyboard (INV-PERF-5)
  //
  // MediaQuery.sizeOf(context) subscribes only to size changes, so keyboard
  // appearance (viewInsets change) must NOT rebuild the message list.
  // Reverting to MediaQuery.of(context).size.width would break this test
  // because `of()` subscribes to the entire MediaQuery, including viewInsets.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation: keyboard appearance does not rebuild message list '
    '(INV-PERF-5)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: ConversationDetailTarget.channel(
            const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'ch-1',
            ),
          ),
          title: '#general',
          messages: _generateMessages(10),
          historyLimited: false,
          hasOlder: false,
        ),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Record build count after initial render stabilizes.
      final initialBuildCount = ConversationMessageList.buildCount;

      // Simulate keyboard appearance via platform viewInsets.
      // This changes viewInsets but NOT size — only MediaQuery.of subscribers
      // would see this as a dependency change.
      tester.view.viewInsets =
          const FakeViewPadding(bottom: 300, left: 0, top: 0, right: 0);
      await tester.pump();

      // With MediaQuery.sizeOf, the message list must NOT rebuild because
      // only viewInsets changed, not size. With MediaQuery.of, this would
      // trigger a full rebuild (buildCount would increase).
      expect(
        ConversationMessageList.buildCount,
        initialBuildCount,
        reason: 'Message list must NOT rebuild when only viewInsets change — '
            'MediaQuery.sizeOf must be used instead of MediaQuery.of '
            '(INV-PERF-5)',
      );

      // Reset view insets for other tests.
      tester.view.resetViewInsets();
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

Widget _buildConversationAppWithSessionSpy(
  _FakeConversationRepository repo,
  _CountingSessionCache sessionSpy,
) {
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
      conversationDetailSessionStoreProvider.overrideWithValue(sessionSpy),
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

/// Spy on [ConversationDetailSessionCache] that counts `saveScrollOffset`
/// calls to verify throttle behavior (INV-PERF-1).
class _CountingSessionCache extends ConversationDetailSessionCache {
  int saveScrollOffsetCount = 0;

  @override
  void saveScrollOffset(
    ConversationDetailTarget target,
    double scrollOffset,
  ) {
    saveScrollOffsetCount++;
    // Don't call super — skip the debounce timer entirely.
    // This test verifies throttle behavior, not persistence timing.
  }
}
