// =============================================================================
// Message Draft Persistence — Session Store Tests
//
// Verifies:
// 1. Draft text survives conversation switch (fromState → toState roundtrip)
// 2. Pending attachments survive conversation switch
// 3. Draft + attachments cleared after send (empty roundtrip)
// 4. clearAll() wipes all session entries (logout cleanup)
// 5. replyToMessage survives roundtrip alongside draft
//
// All tests go RED if session entry persistence is reverted.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

/// Channel scope IDs for test targets.
const _channelScopeId1 = ChannelScopeId(
  serverId: ServerScopeId('server-1'),
  value: 'ch-1',
);

const _channelScopeId2 = ChannelScopeId(
  serverId: ServerScopeId('server-1'),
  value: 'ch-2',
);

final _target1 = ConversationDetailTarget.channel(_channelScopeId1);
final _target2 = ConversationDetailTarget.channel(_channelScopeId2);

void main() {
  group('Draft persistence — session store', () {
    test('draft text survives fromState → toState roundtrip', () {
      final state = ConversationDetailState(
        target: _target1,
        status: ConversationDetailStatus.success,
        title: '#general',
        messages: [_makeMessage('msg-1', 'First message')],
        draft: 'hello world',
      );

      final entry = ConversationDetailSessionEntry.fromState(
        state,
        scrollOffset: 0,
      );
      final restored = entry.toState(_target1);

      expect(restored.draft, 'hello world');
    });

    test('pending attachments survive fromState → toState roundtrip', () {
      const attachment = PendingAttachment(
        path: '/tmp/photo.jpg',
        name: 'photo.jpg',
        mimeType: 'image/jpeg',
      );

      final state = ConversationDetailState(
        target: _target1,
        status: ConversationDetailStatus.success,
        title: '#general',
        messages: [_makeMessage('msg-1', 'First message')],
        draft: 'check this image',
        pendingAttachments: const [attachment],
      );

      final entry = ConversationDetailSessionEntry.fromState(
        state,
        scrollOffset: 0,
      );
      final restored = entry.toState(_target1);

      expect(restored.draft, 'check this image');
      expect(restored.pendingAttachments, hasLength(1));
      expect(restored.pendingAttachments.first.path, '/tmp/photo.jpg');
      expect(restored.pendingAttachments.first.name, 'photo.jpg');
      expect(restored.pendingAttachments.first.mimeType, 'image/jpeg');
    });

    test('empty draft after send roundtrips as empty', () {
      final state = ConversationDetailState(
        target: _target1,
        status: ConversationDetailStatus.success,
        title: '#general',
        messages: [_makeMessage('msg-1', 'First message')],
        draft: '',
        pendingAttachments: const [],
      );

      final entry = ConversationDetailSessionEntry.fromState(
        state,
        scrollOffset: 0,
      );
      final restored = entry.toState(_target1);

      expect(restored.draft, '');
      expect(restored.pendingAttachments, isEmpty);
    });

    test('replyToMessage survives roundtrip alongside draft', () {
      final replyTarget = _makeMessage('msg-1', 'Original message');

      final state = ConversationDetailState(
        target: _target1,
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
      final restored = entry.toState(_target1);

      expect(restored.draft, 'replying to this');
      expect(restored.replyToMessage, isNotNull);
      expect(restored.replyToMessage!.id, 'msg-1');
    });

    test('clearAll() removes all session entries', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final store =
          container.read(conversationDetailSessionStoreProvider.notifier);

      // Save two different conversations.
      store.saveSuccessState(
        ConversationDetailState(
          target: _target1,
          status: ConversationDetailStatus.success,
          title: '#general',
          messages: [_makeMessage('msg-1', 'hello')],
          draft: 'draft for ch-1',
        ),
        scrollOffset: 100,
      );
      store.saveSuccessState(
        ConversationDetailState(
          target: _target2,
          status: ConversationDetailStatus.success,
          title: '#random',
          messages: [_makeMessage('msg-2', 'world')],
          draft: 'draft for ch-2',
        ),
        scrollOffset: 200,
      );

      // Verify both are saved.
      final stateBefore =
          container.read(conversationDetailSessionStoreProvider);
      expect(stateBefore.length, 2);
      expect(stateBefore[_target1]?.draft, 'draft for ch-1');
      expect(stateBefore[_target2]?.draft, 'draft for ch-2');

      // clearAll.
      store.clearAll();

      // Verify all cleared.
      final stateAfter = container.read(conversationDetailSessionStoreProvider);
      expect(stateAfter, isEmpty);
    });

    test('saveSuccessState persists draft from state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final store =
          container.read(conversationDetailSessionStoreProvider.notifier);

      store.saveSuccessState(
        ConversationDetailState(
          target: _target1,
          status: ConversationDetailStatus.success,
          title: '#general',
          messages: [_makeMessage('msg-1', 'hello')],
          draft: 'my draft text',
          pendingAttachments: const [
            PendingAttachment(
              path: '/tmp/file.pdf',
              name: 'file.pdf',
              mimeType: 'application/pdf',
            ),
          ],
        ),
        scrollOffset: 50,
      );

      final entry =
          container.read(conversationDetailSessionStoreProvider)[_target1];
      expect(entry, isNotNull);
      expect(entry!.draft, 'my draft text');
      expect(entry.pendingAttachments, hasLength(1));
      expect(entry.pendingAttachments.first.name, 'file.pdf');
    });

    test('multiple attachments preserved across roundtrip', () {
      const attachments = [
        PendingAttachment(
          path: '/tmp/a.jpg',
          name: 'a.jpg',
          mimeType: 'image/jpeg',
        ),
        PendingAttachment(
          path: '/tmp/b.pdf',
          name: 'b.pdf',
          mimeType: 'application/pdf',
        ),
        PendingAttachment(
          path: '/tmp/c.mp4',
          name: 'c.mp4',
          mimeType: 'video/mp4',
        ),
      ];

      final state = ConversationDetailState(
        target: _target1,
        status: ConversationDetailStatus.success,
        title: '#general',
        messages: [_makeMessage('msg-1', 'First message')],
        draft: 'with files',
        pendingAttachments: attachments,
      );

      final entry = ConversationDetailSessionEntry.fromState(
        state,
        scrollOffset: 0,
      );
      final restored = entry.toState(_target1);

      expect(restored.pendingAttachments, hasLength(3));
      expect(restored.pendingAttachments[0].name, 'a.jpg');
      expect(restored.pendingAttachments[1].name, 'b.pdf');
      expect(restored.pendingAttachments[2].name, 'c.mp4');
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ConversationMessageSummary _makeMessage(String id, String content) {
  return ConversationMessageSummary(
    id: id,
    content: content,
    createdAt: DateTime.parse('2026-06-01T00:00:00Z'),
    senderType: 'human',
    messageType: 'message',
    seq: 1,
  );
}
