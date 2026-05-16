import 'dart:math' as math;

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
// #525: @Mention Autocomplete — Phase A (test-only)
//
// Verifies that typing '@' in the composer triggers a member suggestion
// overlay, selecting a suggestion inserts '@username', and typing partial
// text after '@' filters the suggestions.
//
// Invariants:
//   INV-MENTION-1: Type '@' → member suggestion overlay appears
//   INV-MENTION-2: Tap suggestion → '@username' inserted into TextField
//   INV-MENTION-3: Type '@par' → filtered suggestions matching "par"
//
// All three tests skip: true until Phase B adds @ detection + overlay.
//
// Phase B write set:
//   lib/features/conversation/presentation/page/conversation_detail_page.dart
//   lib/features/conversation/presentation/widgets/mention_suggestion_overlay.dart (NEW)
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-MENTION-1: Type '@' in composer → member suggestion overlay appears
  //
  // The composer currently has no @ detection. Phase B adds onChanged logic
  // to detect '@' and show an overlay with channel members.
  //
  // Currently FAILS: typing '@' does not produce any suggestion overlay.
  // -----------------------------------------------------------------------
  testWidgets(
    'Typing @ in composer shows member suggestion overlay (INV-MENTION-1)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Composer text field must be rendered.
      final inputFinder = find.byKey(const ValueKey('composer-input'));
      expect(inputFinder, findsOneWidget,
          reason: 'Composer text field must be rendered');

      // Type '@' in the composer.
      await tester.enterText(inputFinder, '@');
      await tester.pump();

      // Member suggestion overlay must appear.
      expect(
        find.byKey(const ValueKey('mention-suggestion-overlay')),
        findsOneWidget,
        reason: 'Typing @ must show member suggestion overlay '
            '(INV-MENTION-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-MENTION-2: Tap suggestion → '@username' inserted into TextField
  //
  // After the suggestion overlay appears, tapping a member name should
  // replace the '@' trigger text with '@username ' (with trailing space).
  //
  // Currently FAILS: no suggestion overlay exists to tap.
  // -----------------------------------------------------------------------
  testWidgets(
    'Tap mention suggestion inserts @username into composer (INV-MENTION-2)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Type '@' to trigger suggestions.
      final inputFinder = find.byKey(const ValueKey('composer-input'));
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, '@');
      await tester.pump();

      // Suggestion overlay must be visible.
      expect(
        find.byKey(const ValueKey('mention-suggestion-overlay')),
        findsOneWidget,
        reason: 'Suggestion overlay must appear after typing @',
      );

      // Tap the first suggestion item and read its label.
      final suggestionFinder =
          find.byKey(const ValueKey('mention-suggestion-0'));
      expect(suggestionFinder, findsOneWidget,
          reason: 'At least one member suggestion must be shown');

      // Read the username from the suggestion before tapping.
      final suggestionLabel = tester.widget<Text>(
        find.descendant(of: suggestionFinder, matching: find.byType(Text)),
      );
      final selectedUsername = suggestionLabel.data!;
      expect(selectedUsername.isNotEmpty, isTrue,
          reason: 'Suggestion label must contain a username');

      await tester.tap(suggestionFinder);
      await tester.pumpAndSettle();

      // The composer text must be exactly '@selectedUsername '
      // (with trailing space for continued typing).
      final textField = tester.widget<TextField>(inputFinder);
      final text = textField.controller!.text;
      expect(text, equals('@$selectedUsername '),
          reason: 'Tapping suggestion must insert exactly '
              '@$selectedUsername followed by a space '
              '(INV-MENTION-2)');

      // Suggestion overlay should be dismissed after selection.
      expect(
        find.byKey(const ValueKey('mention-suggestion-overlay')),
        findsNothing,
        reason: 'Suggestion overlay must close after selecting a member',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-MENTION-3: Type '@par' → filtered suggestions matching "par"
  //
  // After typing '@' followed by partial text, the suggestion list should
  // filter to show only members whose name contains the partial text.
  //
  // Currently FAILS: no @ detection or filtering logic exists.
  // -----------------------------------------------------------------------
  testWidgets(
    'Typing @par filters suggestions to matching members (INV-MENTION-3)',
    skip: true,
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Type '@' to trigger suggestions.
      final inputFinder = find.byKey(const ValueKey('composer-input'));
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, '@');
      await tester.pump();

      // Suggestion overlay must appear with multiple members.
      expect(
        find.byKey(const ValueKey('mention-suggestion-overlay')),
        findsOneWidget,
        reason: 'Suggestion overlay must appear after typing @',
      );

      // Before filtering, at least 2 suggestions must be visible.
      expect(
        find.byKey(const ValueKey('mention-suggestion-0')),
        findsOneWidget,
        reason: 'First suggestion must be visible before filtering',
      );
      expect(
        find.byKey(const ValueKey('mention-suggestion-1')),
        findsOneWidget,
        reason: 'Second suggestion must be visible before filtering '
            '(need ≥2 members to test filter)',
      );

      // Read member names from the unfiltered list to identify a
      // matching and non-matching member for the filter query.
      final label0 = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('mention-suggestion-0')),
              matching: find.byType(Text),
            ),
          )
          .data!;
      final label1 = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('mention-suggestion-1')),
              matching: find.byType(Text),
            ),
          )
          .data!;

      // Pick a filter prefix from label0 (first 3 chars) that does NOT
      // match label1. If they share a prefix, use a longer portion.
      final filterPrefix =
          label0.substring(0, math.min(3, label0.length)).toLowerCase();
      final label1Lower = label1.toLowerCase();
      // Sanity: the two labels must differ so filtering is meaningful.
      expect(label0.toLowerCase(), isNot(equals(label1Lower)),
          reason: 'Need distinct member names to test filtering');

      // Now type '@<filterPrefix>' to filter.
      await tester.enterText(inputFinder, '@$filterPrefix');
      await tester.pump();

      // Overlay must still be visible (not dismissed by partial text).
      expect(
        find.byKey(const ValueKey('mention-suggestion-overlay')),
        findsOneWidget,
        reason: 'Suggestion overlay must remain visible while '
            'typing partial match',
      );

      // At least one suggestion matching the filter must be visible.
      // The matching member's name must contain the filter prefix.
      final filteredSuggestion =
          find.byKey(const ValueKey('mention-suggestion-0'));
      expect(filteredSuggestion, findsOneWidget,
          reason: 'At least one filtered suggestion must remain');
      final filteredLabel = tester
          .widget<Text>(
            find.descendant(
              of: filteredSuggestion,
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(filteredLabel.toLowerCase(), contains(filterPrefix),
          reason: 'Visible suggestion must match the filter prefix '
              '"$filterPrefix" (INV-MENTION-3)');

      // If label1 does not match the filter, it must be absent.
      if (!label1Lower.contains(filterPrefix)) {
        expect(
          find.text(label1),
          findsNothing,
          reason: 'Non-matching member "$label1" must be filtered out '
              'when typing @$filterPrefix (INV-MENTION-3)',
        );
      }
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
        content: 'Hello there',
        createdAt: DateTime.parse('2026-05-16T00:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
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
