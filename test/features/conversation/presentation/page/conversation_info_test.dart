import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

// ---------------------------------------------------------------------------
// #532: Conversation Info Page — Phase A
//
// Verifies that a conversation info page can be reached from the
// conversation detail app bar, and that it contains the expected sections
// (members, files, pinned messages) for channels and user info for DMs.
//
// The production entry point is the existing placeholder IconButton keyed
// 'conversation-members-shortcut' in the conversation detail app bar.
// Phase B will wire this button to navigate to the info page.
//
// Invariants:
//   INV-CONV-INFO-1: Tap members toggle → navigates to info page
//   INV-CONV-INFO-2: Info page shows members list section
//   INV-CONV-INFO-3: Info page shows shared files section
//   INV-CONV-INFO-4: DM info page shows user profile info
//
// Phase A → Phase B: All invariants are now active (info page implemented).
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-CONV-INFO-1: Tapping the members toggle button in the app bar
  // navigates to a ConversationInfoPage.
  //
  // Setup: Render conversation detail page, tap the members toggle (keyed
  // 'conversation-members-shortcut'). After navigation, a widget keyed
  // 'conversation-info-page' should appear.
  //
  // skip:true — onPressed is empty stub and no info page exists.
  // -----------------------------------------------------------------------
  testWidgets(
    'Tap members toggle navigates to conversation info page (INV-CONV-INFO-1)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeChannelSnapshot(),
      );

      await tester.pumpWidget(await _buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Members toggle must be present in the app bar.
      final membersToggle =
          find.byKey(const ValueKey('conversation-members-shortcut'));
      expect(membersToggle, findsOneWidget,
          reason: 'Members toggle must be in app bar');

      // Tap the members toggle to navigate.
      await tester.tap(membersToggle);
      await tester.pumpAndSettle();

      // Conversation info page must appear.
      expect(
        find.byKey(const ValueKey('conversation-info-page')),
        findsOneWidget,
        reason: 'Conversation info page must appear after tapping title '
            '(INV-CONV-INFO-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-CONV-INFO-2: The conversation info page shows a members section
  // for channel-type conversations.
  //
  // Setup: Navigate to info page for a channel conversation. A widget
  // keyed 'conversation-info-members-section' must be present.
  //
  // skip:true — info page does not exist.
  // -----------------------------------------------------------------------
  testWidgets(
    'Info page shows members section for channel (INV-CONV-INFO-2)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeChannelSnapshot(),
      );

      await tester.pumpWidget(await _buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Navigate to info page.
      final membersToggle =
          find.byKey(const ValueKey('conversation-members-shortcut'));
      expect(membersToggle, findsOneWidget);
      await tester.tap(membersToggle);
      await tester.pumpAndSettle();

      // Members section must be present.
      expect(
        find.byKey(const ValueKey('conversation-info-members-section')),
        findsOneWidget,
        reason: 'Channel info page must show members section '
            '(INV-CONV-INFO-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-CONV-INFO-3: The conversation info page shows a shared files
  // section for channel-type conversations.
  //
  // Setup: Navigate to info page for a channel conversation. A widget
  // keyed 'conversation-info-files-section' must be present.
  //
  // skip:true — info page does not exist.
  // -----------------------------------------------------------------------
  testWidgets(
    'Info page shows shared files section for channel (INV-CONV-INFO-3)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeChannelSnapshot(),
      );

      await tester.pumpWidget(await _buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Navigate to info page.
      final membersToggle =
          find.byKey(const ValueKey('conversation-members-shortcut'));
      expect(membersToggle, findsOneWidget);
      await tester.tap(membersToggle);
      await tester.pumpAndSettle();

      // Files section must be present.
      expect(
        find.byKey(const ValueKey('conversation-info-files-section')),
        findsOneWidget,
        reason: 'Channel info page must show shared files section '
            '(INV-CONV-INFO-3)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-CONV-INFO-4: For DM-type conversations, the info page shows
  // user profile information (e.g. display name, avatar placeholder).
  //
  // Setup: Render conversation detail page with a DM target, navigate
  // to info page. A widget keyed 'conversation-info-user-profile' must
  // be present.
  //
  // skip:true — info page does not exist.
  // -----------------------------------------------------------------------
  testWidgets(
    'DM info page shows user profile info (INV-CONV-INFO-4)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeDmSnapshot(),
      );

      await tester.pumpWidget(await _buildConversationApp(
        repo,
        isDm: true,
      ));
      await tester.pumpAndSettle();

      // Navigate to info page.
      final membersToggle =
          find.byKey(const ValueKey('conversation-members-shortcut'));
      expect(membersToggle, findsOneWidget);
      await tester.tap(membersToggle);
      await tester.pumpAndSettle();

      // User profile section must be present.
      expect(
        find.byKey(const ValueKey('conversation-info-user-profile')),
        findsOneWidget,
        reason: 'DM info page must show user profile info '
            '(INV-CONV-INFO-4)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a snapshot for a channel conversation.
ConversationDetailSnapshot _makeChannelSnapshot() {
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
        createdAt: DateTime.parse('2026-05-16T14:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
    ],
    historyLimited: false,
    hasOlder: false,
  );
}

/// Creates a snapshot for a DM conversation.
ConversationDetailSnapshot _makeDmSnapshot() {
  return ConversationDetailSnapshot(
    target: ConversationDetailTarget.directMessage(
      const DirectMessageScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'dm-1',
      ),
    ),
    title: 'Alice',
    messages: [
      ConversationMessageSummary(
        id: 'msg-1',
        content: 'Hey there',
        createdAt: DateTime.parse('2026-05-16T14:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
    ],
    historyLimited: false,
    hasOlder: false,
  );
}

Future<Widget> _buildConversationApp(
  _FakeConversationRepository repo, {
  bool isDm = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final target = isDm
      ? ConversationDetailTarget.directMessage(
          const DirectMessageScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'dm-1',
          ),
        )
      : ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-1',
          ),
        );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
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
