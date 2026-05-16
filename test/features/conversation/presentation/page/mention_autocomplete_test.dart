import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #525: @Mention Autocomplete — Phase B
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
// Phase B enabled — all tests un-skipped.
// ---------------------------------------------------------------------------

/// Test members used across all tests.
/// member-3 has a multi-word agentName to exercise the mention-safe handle.
const _testMembers = [
  ChannelMember(
    id: 'member-1',
    channelId: 'ch-1',
    userId: 'user-alice',
    userName: 'Alice',
  ),
  ChannelMember(
    id: 'member-2',
    channelId: 'ch-1',
    userId: 'user-parker',
    userName: 'Parker',
  ),
  ChannelMember(
    id: 'member-3',
    channelId: 'ch-1',
    agentId: 'agent-bob',
    agentName: 'Bob Smith',
  ),
];

void main() {
  // -----------------------------------------------------------------------
  // INV-MENTION-1: Type '@' in composer → member suggestion overlay appears
  // -----------------------------------------------------------------------
  testWidgets(
    'Typing @ in composer shows member suggestion overlay (INV-MENTION-1)',
    (tester) async {
      final repo = _FakeConversationRepository(snapshot: _makeSnapshot());

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Composer text field must be rendered.
      final inputFinder = find.byKey(const ValueKey('composer-input'));
      expect(inputFinder, findsOneWidget,
          reason: 'Composer text field must be rendered');

      // Type '@' in the composer.
      await tester.enterText(inputFinder, '@');
      await tester.pumpAndSettle();

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
  // -----------------------------------------------------------------------
  testWidgets(
    'Tap mention suggestion inserts @username into composer (INV-MENTION-2)',
    (tester) async {
      final repo = _FakeConversationRepository(snapshot: _makeSnapshot());

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Type '@' to trigger suggestions.
      final inputFinder = find.byKey(const ValueKey('composer-input'));
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, '@');
      await tester.pumpAndSettle();

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
      // The suggestion item contains two Text widgets: avatar initial + name.
      // We want the name (last Text child).
      final textFinder = find.descendant(
        of: suggestionFinder,
        matching: find.byType(Text),
      );
      final suggestionLabel = tester.widget<Text>(textFinder.last);
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
  // -----------------------------------------------------------------------
  testWidgets(
    'Typing @par filters suggestions to matching members (INV-MENTION-3)',
    (tester) async {
      final repo = _FakeConversationRepository(snapshot: _makeSnapshot());

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Type '@' to trigger suggestions.
      final inputFinder = find.byKey(const ValueKey('composer-input'));
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, '@');
      await tester.pumpAndSettle();

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

      // Type '@par' to filter — should match "Parker" but not "Alice" or "Bob".
      await tester.enterText(inputFinder, '@par');
      await tester.pumpAndSettle();

      // Overlay must still be visible (not dismissed by partial text).
      expect(
        find.byKey(const ValueKey('mention-suggestion-overlay')),
        findsOneWidget,
        reason: 'Suggestion overlay must remain visible while '
            'typing partial match',
      );

      // "Parker" must remain visible.
      expect(
        find.text('Parker'),
        findsOneWidget,
        reason: 'Member "Parker" must be visible when filtering by '
            '"par" (INV-MENTION-3)',
      );

      // "Alice" must be filtered out.
      expect(
        find.text('Alice'),
        findsNothing,
        reason: 'Non-matching member "Alice" must be filtered out '
            'when typing @par (INV-MENTION-3)',
      );

      // "Bob Smith" must be filtered out.
      expect(
        find.text('Bob Smith'),
        findsNothing,
        reason: 'Non-matching member "Bob Smith" must be filtered out '
            'when typing @par (INV-MENTION-3)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-MENTION-4: Multi-word display name → mention-safe handle inserted
  //
  // Regression: member with displayName "Bob Smith" must be inserted as
  // '@BobSmith ' (spaces stripped) so it round-trips through MentionSyntax
  // which only recognizes @([\w][\w.\-]*).
  // -----------------------------------------------------------------------
  testWidgets(
    'Multi-word display name inserts mention-safe handle (INV-MENTION-4)',
    (tester) async {
      final repo = _FakeConversationRepository(snapshot: _makeSnapshot());

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Type '@bob' to filter to "Bob Smith".
      final inputFinder = find.byKey(const ValueKey('composer-input'));
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, '@bob');
      await tester.pumpAndSettle();

      // Suggestion overlay must appear.
      expect(
        find.byKey(const ValueKey('mention-suggestion-overlay')),
        findsOneWidget,
        reason: 'Suggestion overlay must appear after typing @bob',
      );

      // "Bob Smith" must be visible in overlay (displayed by displayName).
      expect(
        find.text('Bob Smith'),
        findsOneWidget,
        reason: 'Member "Bob Smith" must be visible when filtering by '
            '"bob"',
      );

      // Tap the "Bob Smith" suggestion.
      final suggestionFinder =
          find.byKey(const ValueKey('mention-suggestion-0'));
      expect(suggestionFinder, findsOneWidget);
      await tester.tap(suggestionFinder);
      await tester.pumpAndSettle();

      // The composer must contain '@BobSmith ' (mention-safe, no space).
      final textField = tester.widget<TextField>(inputFinder);
      final text = textField.controller!.text;
      expect(text, equals('@BobSmith '),
          reason: 'Multi-word display name "Bob Smith" must be inserted '
              'as mention-safe handle "@BobSmith" (spaces stripped) so '
              'it round-trips through MentionSyntax (INV-MENTION-4)');
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
      channelMemberRepositoryProvider
          .overrideWithValue(const _FakeChannelMemberRepository()),
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

class _FakeChannelMemberRepository implements ChannelMemberRepository {
  const _FakeChannelMemberRepository();

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    return _testMembers;
  }

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
