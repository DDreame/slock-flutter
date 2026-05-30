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
// #530: Message Precise Timestamp — Phase A
//
// Verifies that tapping a non-system message bubble reveals a precise
// timestamp (date + time), and that system messages do not respond to
// the timestamp tap interaction.
//
// Invariants:
//   INV-TIMESTAMP-1: Tap non-system message → precise timestamp appears
//   INV-TIMESTAMP-2: Timestamp auto-dismisses (second tap or timeout)
//   INV-TIMESTAMP-3: System message tap does not show timestamp
//
// Phase A — INV-TIMESTAMP-1 and INV-TIMESTAMP-2 are skip:true (feature
// not yet implemented). INV-TIMESTAMP-3 is active (system messages
// already have no onTap handler).
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-TIMESTAMP-1: Tapping a non-system message reveals a precise
  // timestamp overlay/widget (keyed 'precise-timestamp') containing
  // the full date and time.
  //
  // Setup: 2 messages, tap the first (human) message bubble.
  // The precise timestamp widget must appear.
  //
  // skip:true — no tap-to-timestamp feature exists yet. Non-threaded
  // message taps currently have no onTap handler.
  // -----------------------------------------------------------------------
  testWidgets(
    'Tap non-system message shows precise timestamp (INV-TIMESTAMP-1)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Precise timestamp must not be visible initially.
      expect(
        find.byKey(const ValueKey('precise-timestamp')),
        findsNothing,
        reason: 'Precise timestamp must not be visible before tapping',
      );

      // Tap on the message shell (non-system, non-threaded message).
      final msgShell = find.byKey(const ValueKey('message-shell-msg-1'));
      expect(msgShell, findsOneWidget,
          reason: 'Message shell must be rendered');
      await tester.tap(msgShell);
      // Advance past the 300ms double-tap window so the deferred single-tap
      // fires, but NOT past the 3-second auto-dismiss timer.
      // pumpAndSettle() would advance through all timers (including the 3s
      // auto-dismiss), hiding the timestamp before the assertion.
      await tester.pump(const Duration(milliseconds: 500));

      // Precise timestamp must appear.
      expect(
        find.byKey(const ValueKey('precise-timestamp')),
        findsOneWidget,
        reason: 'Precise timestamp must appear after tapping non-system '
            'message (INV-TIMESTAMP-1)',
      );

      // The timestamp should contain the precise date + time (HH:mm:ss)
      // derived from msg-1's createdAt (2026-05-16T14:30:45Z).
      final expectedLocal = DateTime.parse('2026-05-16T14:30:45Z').toLocal();
      final expectedHms = '${expectedLocal.hour.toString().padLeft(2, '0')}:'
          '${expectedLocal.minute.toString().padLeft(2, '0')}:'
          '${expectedLocal.second.toString().padLeft(2, '0')}';
      final timestampFinder = find.byKey(const ValueKey('precise-timestamp'));
      final textInTimestamp = find.descendant(
        of: timestampFinder,
        matching: find.textContaining(expectedHms),
      );
      expect(textInTimestamp, findsOneWidget,
          reason: 'Precise timestamp must contain the full HH:mm:ss '
              '($expectedHms) from the seeded createdAt');
    },
  );

  // -----------------------------------------------------------------------
  // INV-TIMESTAMP-2: The precise timestamp auto-dismisses — either on
  // a second tap or after a timeout.
  //
  // Setup: Tap message to show timestamp, then tap again (or wait).
  // The timestamp must disappear.
  //
  // skip:true — feature not yet implemented.
  // -----------------------------------------------------------------------
  testWidgets(
    'Precise timestamp dismisses on second tap (INV-TIMESTAMP-2)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // Tap to show timestamp.
      final msgShell = find.byKey(const ValueKey('message-shell-msg-1'));
      await tester.tap(msgShell);
      // Advance past 300ms double-tap window but not 3s auto-dismiss.
      await tester.pump(const Duration(milliseconds: 500));

      // Timestamp must be visible.
      expect(
        find.byKey(const ValueKey('precise-timestamp')),
        findsOneWidget,
        reason: 'Precise timestamp must appear after first tap',
      );

      // Tap again to dismiss. The second tap arrives within 300ms of the
      // previous tap-timer completing, so it's treated as a fresh single-tap
      // (not a double-tap). Wait 400ms for the double-tap window to elapse
      // before the second tap so it's a clean single-tap toggle.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(msgShell);
      // Advance past the 300ms deferred tap window.
      await tester.pump(const Duration(milliseconds: 500));

      // Timestamp must disappear.
      expect(
        find.byKey(const ValueKey('precise-timestamp')),
        findsNothing,
        reason: 'Precise timestamp must disappear after second tap '
            '(INV-TIMESTAMP-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-TIMESTAMP-3: System messages do not show precise timestamp
  // on tap.
  //
  // Setup: Snapshot includes a system message. Tap the system message
  // shell. No precise timestamp widget should appear.
  //
  // Active — system messages already have no onTap handler (only
  // onLongPress for context menu). This test validates the invariant
  // is preserved as the timestamp feature is added for non-system msgs.
  // -----------------------------------------------------------------------
  testWidgets(
    'System message tap does not show timestamp (INV-TIMESTAMP-3)',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: _makeSnapshotWithSystemMessage(),
      );

      await tester.pumpWidget(_buildConversationApp(repo));
      await tester.pumpAndSettle();

      // System message shell must be rendered.
      final systemShell = find.byKey(const ValueKey('message-shell-sys-1'));
      expect(systemShell, findsOneWidget,
          reason: 'System message shell must be rendered');

      // Tap the system message.
      await tester.tap(systemShell);
      await tester.pumpAndSettle();

      // No precise timestamp should appear.
      expect(
        find.byKey(const ValueKey('precise-timestamp')),
        findsNothing,
        reason: 'System message must not show precise timestamp on tap '
            '(INV-TIMESTAMP-3)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a snapshot with 2 human messages for timestamp testing.
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
        createdAt: DateTime.parse('2026-05-16T14:30:45Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
      ConversationMessageSummary(
        id: 'msg-2',
        content: 'How are you?',
        createdAt: DateTime.parse('2026-05-16T14:35:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 2,
      ),
    ],
    historyLimited: false,
    hasOlder: false,
  );
}

/// Creates a snapshot with a system message for INV-TIMESTAMP-3.
ConversationDetailSnapshot _makeSnapshotWithSystemMessage() {
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
        createdAt: DateTime.parse('2026-05-16T14:30:45Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
      ConversationMessageSummary(
        id: 'sys-1',
        content: 'Alice joined the channel',
        createdAt: DateTime.parse('2026-05-16T14:32:00Z'),
        senderType: 'human',
        messageType: 'system',
        seq: 2,
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
        displayName: 'Alice',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}
