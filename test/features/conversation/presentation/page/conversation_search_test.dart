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
// #528: Conversation Search — Phase A
//
// Verifies that the conversation app bar has a search button, tapping it
// shows a search field, and typing a query highlights the current match
// message with a bubble-level decoration.
//
// Invariants:
//   INV-CONV-SEARCH-1: Search button visible in conversation app bar
//   INV-CONV-SEARCH-2: Tap search button → search field appears
//   INV-CONV-SEARCH-3: Current search match has bubble-level highlight
//
// INV-1 and INV-2 are active (already pass on production code).
// INV-3 is skip:true — targets the gap: current-match bubble decoration
// (not yet implemented).
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-CONV-SEARCH-1: Search icon visible in conversation app bar.
  //
  // The app bar should contain a search toggle button (keyed
  // 'conversation-search-toggle') when the conversation is loaded.
  // -----------------------------------------------------------------------
  testWidgets(
    'Search button visible in conversation app bar (INV-CONV-SEARCH-1)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Search toggle button must be present in the app bar.
      expect(
        find.byKey(const ValueKey('conversation-search-toggle')),
        findsOneWidget,
        reason: 'Search button must be visible in conversation app bar '
            '(INV-CONV-SEARCH-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-CONV-SEARCH-2: Tapping search button shows search field.
  //
  // Before tapping: search bar hidden. After tapping the search toggle:
  // search bar (keyed 'conversation-search-bar') appears with an input
  // field (keyed 'conversation-search-input').
  // -----------------------------------------------------------------------
  testWidgets(
    'Tap search button shows search field (INV-CONV-SEARCH-2)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Search bar must not be visible initially.
      expect(
        find.byKey(const ValueKey('conversation-search-bar')),
        findsNothing,
        reason: 'Search bar must not be visible before tapping search',
      );

      // Tap the search toggle.
      final searchToggle =
          find.byKey(const ValueKey('conversation-search-toggle'));
      expect(searchToggle, findsOneWidget);
      await tester.tap(searchToggle);
      await tester.pumpAndSettle();

      // Search bar must appear.
      expect(
        find.byKey(const ValueKey('conversation-search-bar')),
        findsOneWidget,
        reason: 'Search bar must appear after tapping search toggle '
            '(INV-CONV-SEARCH-2)',
      );

      // Search input field must be present inside the bar.
      expect(
        find.byKey(const ValueKey('conversation-search-input')),
        findsOneWidget,
        reason: 'Search input field must be present in the search bar',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-CONV-SEARCH-3: Current search match has bubble-level highlight.
  //
  // Typing a query that matches one message must:
  // (a) render a highlight decoration on the current-match message bubble
  //     (keyed 'search-current-match-$msgId')
  // (b) NOT render that decoration on non-matching messages
  //
  // Production key for current match wrapper:
  //   ValueKey('search-current-match-$msgId')
  //
  // skip:true — bubble-level current-match decoration is NOT yet
  // implemented. Text-level highlight via highlightQuery exists, but
  // no per-bubble visual distinction for the CURRENT match.
  // -----------------------------------------------------------------------
  testWidgets(
    'Current search match has bubble-level highlight (INV-CONV-SEARCH-3)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Open the search bar.
      final searchToggle =
          find.byKey(const ValueKey('conversation-search-toggle'));
      expect(searchToggle, findsOneWidget);
      await tester.tap(searchToggle);
      await tester.pumpAndSettle();

      // Search input must be visible.
      final searchInput =
          find.byKey(const ValueKey('conversation-search-input'));
      expect(searchInput, findsOneWidget);

      // Type a query that matches "Hello world" (msg-1 only).
      await tester.enterText(searchInput, 'Hello');
      await tester.pumpAndSettle();

      // Current-match message (msg-1) must have a bubble-level highlight
      // decoration widget keyed 'search-current-match-msg-1'.
      expect(
        find.byKey(const ValueKey('search-current-match-msg-1')),
        findsOneWidget,
        reason: 'Current search match (msg-1) must have bubble-level '
            'highlight decoration (INV-CONV-SEARCH-3)',
      );

      // Non-matching messages must NOT have the decoration.
      expect(
        find.byKey(const ValueKey('search-current-match-msg-2')),
        findsNothing,
        reason: 'Non-matching message (msg-2) must not have '
            'current-match highlight',
      );
      expect(
        find.byKey(const ValueKey('search-current-match-msg-3')),
        findsNothing,
        reason: 'Non-matching message (msg-3) must not have '
            'current-match highlight',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a snapshot with 3 messages for search testing.
ConversationDetailSnapshot _makeSnapshot() {
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
        content: 'Hello world',
        createdAt: DateTime.parse('2026-05-16T00:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
      ConversationMessageSummary(
        id: 'msg-2',
        content: 'How are you doing?',
        createdAt: DateTime.parse('2026-05-16T00:10:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 2,
      ),
      ConversationMessageSummary(
        id: 'msg-3',
        content: 'Goodbye for now',
        createdAt: DateTime.parse('2026-05-16T00:20:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 3,
      ),
    ],
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
