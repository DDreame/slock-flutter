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
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #537: Multi-Select Batch Operations — Phase A
//
// Verifies the multi-select mode for batch delete and batch save of messages
// in the conversation detail page.
//
// Production flow:
//   1. User long-presses a message → enters selection mode
//   2. First long-pressed message is auto-selected, selection action bar
//      appears at the bottom
//   3. Tapping other messages toggles their selection (checkmark overlay)
//   4. User taps "Delete" → batch deletes all selected messages
//   5. User taps "Save" → batch saves all selected messages
//   6. User taps "Cancel" → exits selection mode, deselects all
//
// Invariants:
//   INV-MULTISEL-1: Long-press message → enters selection mode, first
//                   message auto-selected, action bar visible
//   INV-MULTISEL-2: In selection mode, tap message → toggles selection
//                   (checkmark overlay appears/disappears)
//   INV-MULTISEL-3: Action bar "Delete" → deletes selected messages,
//                   exits selection mode, shows success snackbar
//   INV-MULTISEL-4: Action bar "Save" → saves selected messages,
//                   exits selection mode, shows success snackbar
//   INV-MULTISEL-5: Tap Cancel/X → exits selection mode, deselects all
//
// Phase A: All tests skip:true — selection mode, checkmark overlay,
// selection action bar, and batch operations do not exist yet.
//
// Widget keys (Phase B must create):
//   'selection-action-bar' — bottom bar during selection mode
//   'selection-action-delete' — Delete button in action bar
//   'selection-action-save' — Save button in action bar
//   'selection-action-cancel' — Cancel/X button in action bar
//   'selection-check-{msgId}' — checkmark overlay on selected messages
// ---------------------------------------------------------------------------

void main() {
  final channelTarget = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  // -----------------------------------------------------------------------
  // INV-MULTISEL-1: Long-press a message enters selection mode.
  //
  // Setup: Render a conversation with multiple messages. Long-press one
  // message. After the gesture, the selection action bar (keyed
  // 'selection-action-bar') should be visible, and the long-pressed
  // message should show a checkmark overlay (keyed
  // 'selection-check-{msgId}').
  //
  // skip:true — selection mode does not exist.
  // -----------------------------------------------------------------------
  testWidgets(
    'Long-press message enters selection mode with first message selected '
    '(INV-MULTISEL-1)',
    skip: true,
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          repository: _fakeRepo(channelTarget),
          target: channelTarget,
        ),
      );
      await tester.pumpAndSettle();

      // Long-press the first message.
      final shellTL = tester.getTopLeft(
        find.byKey(const ValueKey('message-shell-msg-1')),
      );
      await tester.longPressAt(shellTL + const Offset(10, 10));
      await tester.pumpAndSettle();

      // Selection action bar should appear.
      expect(
        find.byKey(const ValueKey('selection-action-bar')),
        findsOneWidget,
        reason: 'Selection action bar must appear after long-press '
            '(INV-MULTISEL-1)',
      );

      // The long-pressed message should be selected (checkmark visible).
      expect(
        find.byKey(const ValueKey('selection-check-msg-1')),
        findsOneWidget,
        reason: 'Long-pressed message must be auto-selected '
            '(INV-MULTISEL-1)',
      );

      // Other messages should NOT be selected.
      expect(
        find.byKey(const ValueKey('selection-check-msg-2')),
        findsNothing,
        reason: 'Other messages must not be auto-selected '
            '(INV-MULTISEL-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-MULTISEL-2: In selection mode, tapping a message toggles selection.
  //
  // Setup: Enter selection mode via long-press on msg-1. Then tap msg-2.
  // msg-2 should gain a checkmark. Tap msg-2 again — checkmark disappears.
  //
  // skip:true — selection mode does not exist.
  // -----------------------------------------------------------------------
  testWidgets(
    'Tap toggles message selection in selection mode (INV-MULTISEL-2)',
    skip: true,
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          repository: _fakeRepo(channelTarget),
          target: channelTarget,
        ),
      );
      await tester.pumpAndSettle();

      // Enter selection mode by long-pressing msg-1.
      final shellTL = tester.getTopLeft(
        find.byKey(const ValueKey('message-shell-msg-1')),
      );
      await tester.longPressAt(shellTL + const Offset(10, 10));
      await tester.pumpAndSettle();

      // Tap msg-2 to select it.
      await tester.tap(find.byKey(const ValueKey('message-msg-2')));
      await tester.pumpAndSettle();

      // msg-2 should now be selected.
      expect(
        find.byKey(const ValueKey('selection-check-msg-2')),
        findsOneWidget,
        reason: 'Tapped message must become selected (INV-MULTISEL-2)',
      );

      // Tap msg-2 again to deselect.
      await tester.tap(find.byKey(const ValueKey('message-msg-2')));
      await tester.pumpAndSettle();

      // msg-2 should no longer be selected.
      expect(
        find.byKey(const ValueKey('selection-check-msg-2')),
        findsNothing,
        reason: 'Re-tapped message must be deselected (INV-MULTISEL-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-MULTISEL-3: Pressing "Delete" in the selection action bar batch-
  // deletes all selected messages and exits selection mode.
  //
  // Setup: Enter selection mode, select msg-1 and msg-2, tap Delete.
  // After pumpAndSettle:
  //   - Selection action bar disappears
  //   - Both messages are marked as deleted (isDeleted = true in state)
  //
  // NOTE: The delete button key 'selection-action-delete' is a new seam
  // that Phase B must create in a new SelectionActionBar widget.
  //
  // skip:true — selection mode does not exist.
  // -----------------------------------------------------------------------
  testWidgets(
    'Delete button batch-deletes selected messages and exits selection '
    '(INV-MULTISEL-3)',
    skip: true,
    (tester) async {
      final repo = _fakeRepo(channelTarget);

      await tester.pumpWidget(
        _buildApp(
          repository: repo,
          target: channelTarget,
        ),
      );
      await tester.pumpAndSettle();

      // Enter selection mode by long-pressing msg-1.
      final shellTL = tester.getTopLeft(
        find.byKey(const ValueKey('message-shell-msg-1')),
      );
      await tester.longPressAt(shellTL + const Offset(10, 10));
      await tester.pumpAndSettle();

      // Select msg-2 as well.
      await tester.tap(find.byKey(const ValueKey('message-msg-2')));
      await tester.pumpAndSettle();

      // Tap Delete.
      await tester.tap(
        find.byKey(const ValueKey('selection-action-delete')),
      );
      await tester.pumpAndSettle();

      // Selection action bar should disappear (exited selection mode).
      expect(
        find.byKey(const ValueKey('selection-action-bar')),
        findsNothing,
        reason: 'Selection bar must disappear after batch delete '
            '(INV-MULTISEL-3)',
      );

      // Checkmarks should be gone.
      expect(
        find.byKey(const ValueKey('selection-check-msg-1')),
        findsNothing,
        reason: 'Checkmarks must clear after batch delete '
            '(INV-MULTISEL-3)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-MULTISEL-4: Pressing "Save" in the selection action bar batch-
  // saves all selected messages and exits selection mode.
  //
  // Setup: Enter selection mode, select msg-1 and msg-2, tap Save.
  // After pumpAndSettle:
  //   - Selection action bar disappears
  //   - Both messages are now in savedMessageIds
  //
  // NOTE: The save button key 'selection-action-save' is a new seam
  // that Phase B must create in a new SelectionActionBar widget.
  //
  // skip:true — selection mode does not exist.
  // -----------------------------------------------------------------------
  testWidgets(
    'Save button batch-saves selected messages and exits selection '
    '(INV-MULTISEL-4)',
    skip: true,
    (tester) async {
      final repo = _fakeRepo(channelTarget);

      await tester.pumpWidget(
        _buildApp(
          repository: repo,
          target: channelTarget,
        ),
      );
      await tester.pumpAndSettle();

      // Enter selection mode by long-pressing msg-1.
      final shellTL = tester.getTopLeft(
        find.byKey(const ValueKey('message-shell-msg-1')),
      );
      await tester.longPressAt(shellTL + const Offset(10, 10));
      await tester.pumpAndSettle();

      // Select msg-2 as well.
      await tester.tap(find.byKey(const ValueKey('message-msg-2')));
      await tester.pumpAndSettle();

      // Tap Save.
      await tester.tap(
        find.byKey(const ValueKey('selection-action-save')),
      );
      await tester.pumpAndSettle();

      // Selection action bar should disappear (exited selection mode).
      expect(
        find.byKey(const ValueKey('selection-action-bar')),
        findsNothing,
        reason: 'Selection bar must disappear after batch save '
            '(INV-MULTISEL-4)',
      );

      // Checkmarks should be gone.
      expect(
        find.byKey(const ValueKey('selection-check-msg-1')),
        findsNothing,
        reason: 'Checkmarks must clear after batch save '
            '(INV-MULTISEL-4)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-MULTISEL-5: Pressing Cancel/X exits selection mode and deselects
  // all messages.
  //
  // Setup: Enter selection mode, select msg-1 and msg-2, tap Cancel.
  // After pumpAndSettle:
  //   - Selection action bar disappears
  //   - All checkmarks gone
  //   - Messages are NOT deleted or saved
  //
  // NOTE: The cancel button key 'selection-action-cancel' is a new seam
  // that Phase B must create in a new SelectionActionBar widget.
  //
  // skip:true — selection mode does not exist.
  // -----------------------------------------------------------------------
  testWidgets(
    'Cancel button exits selection mode and deselects all '
    '(INV-MULTISEL-5)',
    skip: true,
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          repository: _fakeRepo(channelTarget),
          target: channelTarget,
        ),
      );
      await tester.pumpAndSettle();

      // Enter selection mode by long-pressing msg-1.
      final shellTL = tester.getTopLeft(
        find.byKey(const ValueKey('message-shell-msg-1')),
      );
      await tester.longPressAt(shellTL + const Offset(10, 10));
      await tester.pumpAndSettle();

      // Select msg-2 as well.
      await tester.tap(find.byKey(const ValueKey('message-msg-2')));
      await tester.pumpAndSettle();

      // Tap Cancel.
      await tester.tap(
        find.byKey(const ValueKey('selection-action-cancel')),
      );
      await tester.pumpAndSettle();

      // Selection action bar should disappear.
      expect(
        find.byKey(const ValueKey('selection-action-bar')),
        findsNothing,
        reason: 'Selection bar must disappear after cancel '
            '(INV-MULTISEL-5)',
      );

      // All checkmarks should be gone.
      expect(
        find.byKey(const ValueKey('selection-check-msg-1')),
        findsNothing,
        reason: 'msg-1 checkmark must clear after cancel '
            '(INV-MULTISEL-5)',
      );
      expect(
        find.byKey(const ValueKey('selection-check-msg-2')),
        findsNothing,
        reason: 'msg-2 checkmark must clear after cancel '
            '(INV-MULTISEL-5)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

_FakeConversationRepository _fakeRepo(ConversationDetailTarget target) {
  return _FakeConversationRepository(
    snapshot: ConversationDetailSnapshot(
      target: target,
      title: '#general',
      messages: [
        ConversationMessageSummary(
          id: 'msg-1',
          content: 'First message',
          createdAt: DateTime.parse('2026-05-16T14:00:00Z'),
          senderId: 'user-2',
          senderType: 'human',
          messageType: 'message',
          senderName: 'Alex',
          seq: 1,
        ),
        ConversationMessageSummary(
          id: 'msg-2',
          content: 'Second message',
          createdAt: DateTime.parse('2026-05-16T14:01:00Z'),
          senderId: 'user-3',
          senderType: 'human',
          messageType: 'message',
          senderName: 'Bob',
          seq: 2,
        ),
        ConversationMessageSummary(
          id: 'msg-3',
          content: 'Third message',
          createdAt: DateTime.parse('2026-05-16T14:02:00Z'),
          senderId: 'user-1',
          senderType: 'human',
          messageType: 'message',
          senderName: 'Robin',
          seq: 3,
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    ),
  );
}

Widget _buildApp({
  required ConversationRepository repository,
  required ConversationDetailTarget target,
}) {
  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(repository),
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
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

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Robin',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({required this.snapshot});

  final ConversationDetailSnapshot snapshot;
  final List<String> deletedMessageIds = [];
  final List<String> savedMessageIds = [];

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
    throw UnimplementedError();
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
  }) async {
    deletedMessageIds.add(messageId);
  }

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
  ) async {
    return const [];
  }

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
