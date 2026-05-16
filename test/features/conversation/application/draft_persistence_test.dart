import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

// ---------------------------------------------------------------------------
// #529: Draft Persistence — Phase A
//
// Verifies that the draft text and reply-to context survive a
// conversation switch via the ConversationDetailSessionStore roundtrip
// (fromState → toState).
//
// The production seam is ConversationDetailSessionEntry: fromState()
// snapshots state fields into the session entry, toState() restores them
// when the user returns to the conversation.
//
// Invariants:
//   INV-DRAFT-1: Draft text survives session roundtrip (fromState → toState)
//   INV-DRAFT-2: Draft is empty after send (no stale draft on restore)
//   INV-DRAFT-3: replyToMessage survives session roundtrip with draft
//
// Phase A — INV-DRAFT-1 and INV-DRAFT-3 are skip:true (fromState does
// not yet persist draft or replyToMessage).
// INV-DRAFT-2 is active (send clears draft; empty draft roundtrips today).
// ---------------------------------------------------------------------------

/// Channel scope ID used across all tests.
const _channelScopeId = ChannelScopeId(
  serverId: ServerScopeId('server-1'),
  value: 'ch-1',
);

final _target = ConversationDetailTarget.channel(_channelScopeId);

void main() {
  // -----------------------------------------------------------------------
  // INV-DRAFT-1: Draft text roundtrip through session entry.
  //
  // Setup: ConversationDetailState with draft = 'hello world', status =
  // success. Snapshot via fromState(), restore via toState(). The
  // restored state must have draft == 'hello world'.
  //
  // skip:true — fromState() does not persist draft yet.
  // -----------------------------------------------------------------------
  test(
    'Draft text survives session roundtrip (INV-DRAFT-1)',
    () {
      final state = ConversationDetailState(
        target: _target,
        status: ConversationDetailStatus.success,
        title: '#general',
        messages: [_makeMessage('msg-1', 'First message')],
        draft: 'hello world',
      );

      final entry = ConversationDetailSessionEntry.fromState(
        state,
        scrollOffset: 0,
      );
      final restored = entry.toState(_target);

      expect(
        restored.draft,
        'hello world',
        reason: 'Draft text must survive fromState → toState roundtrip '
            '(INV-DRAFT-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-DRAFT-2: After a successful send, draft is empty. When this
  // empty-draft state is persisted and restored, the draft remains empty.
  //
  // This validates that no stale draft text leaks into a restored session
  // after the user has already sent the message.
  // -----------------------------------------------------------------------
  test(
    'Empty draft after send roundtrips as empty (INV-DRAFT-2)',
    () {
      final state = ConversationDetailState(
        target: _target,
        status: ConversationDetailStatus.success,
        title: '#general',
        messages: [_makeMessage('msg-1', 'First message')],
        draft: '', // cleared after send
      );

      final entry = ConversationDetailSessionEntry.fromState(
        state,
        scrollOffset: 0,
      );
      final restored = entry.toState(_target);

      expect(
        restored.draft,
        '',
        reason: 'Empty draft must remain empty after roundtrip '
            '(INV-DRAFT-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-DRAFT-3: replyToMessage survives session roundtrip alongside draft.
  //
  // Setup: State has draft = 'replying…' and replyToMessage pointing to
  // msg-1. After fromState → toState, both must be restored.
  //
  // skip:true — fromState() does not persist replyToMessage yet.
  // -----------------------------------------------------------------------
  test(
    'replyToMessage survives session roundtrip with draft (INV-DRAFT-3)',
    () {
      final replyTarget = _makeMessage('msg-1', 'Original message');

      final state = ConversationDetailState(
        target: _target,
        status: ConversationDetailStatus.success,
        title: '#general',
        messages: [replyTarget],
        draft: 'replying to this',
        replyToMessage: replyTarget,
      );

      final entry = ConversationDetailSessionEntry.fromState(
        state,
        scrollOffset: 0,
      );
      final restored = entry.toState(_target);

      expect(
        restored.draft,
        'replying to this',
        reason: 'Draft text must survive roundtrip alongside replyToMessage '
            '(INV-DRAFT-3)',
      );
      expect(
        restored.replyToMessage,
        isNotNull,
        reason: 'replyToMessage must survive fromState → toState roundtrip '
            '(INV-DRAFT-3)',
      );
      expect(
        restored.replyToMessage!.id,
        'msg-1',
        reason: 'replyToMessage.id must match original (INV-DRAFT-3)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ConversationMessageSummary _makeMessage(String id, String content) {
  return ConversationMessageSummary(
    id: id,
    content: content,
    createdAt: DateTime.parse('2026-05-16T00:00:00Z'),
    senderType: 'human',
    messageType: 'message',
    seq: 1,
  );
}
