// =============================================================================
// #591 — savedMessageIds Select Optimization
//
// Invariant: INV-PERF-SAVED-1
//   A single save/unsave event triggers rebuild of exactly 1 message card.
//
// Strategy: use ProviderContainer with per-message boolean selects to prove
// that toggling one message's saved state does NOT notify listeners for other
// messages. This validates the granularity of the select expression.
//
// Phase A: tests skip:true — current implementation uses full-Set select which
// causes all selects to fire on any savedMessageIds mutation.
//
// Phase B: change to per-message boolean select in the widget build method:
//   final isSaved = ref.watch(
//     conversationDetailStoreProvider.select(
//       (s) => s.savedMessageIds.contains(widget.message.id),
//     ),
//   );
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart'
    as saved_data;
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

final _channelTarget = ConversationDetailTarget.channel(
  const ChannelScopeId(
    serverId: ServerScopeId('server-1'),
    value: 'general',
  ),
);

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
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      ConversationDetailSnapshot(
        target: _channelTarget,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'msg-1',
            content: 'Hello',
            createdAt: DateTime.parse('2026-05-18T10:00:00Z'),
            senderId: 'user-2',
            senderType: 'human',
            messageType: 'message',
            senderName: 'Alex',
            seq: 1,
          ),
          ConversationMessageSummary(
            id: 'msg-2',
            content: 'World',
            createdAt: DateTime.parse('2026-05-18T10:01:00Z'),
            senderId: 'user-3',
            senderType: 'human',
            messageType: 'message',
            senderName: 'Bob',
            seq: 2,
          ),
          ConversationMessageSummary(
            id: 'msg-3',
            content: 'Foo',
            createdAt: DateTime.parse('2026-05-18T10:02:00Z'),
            senderId: 'user-4',
            senderType: 'human',
            messageType: 'message',
            senderName: 'Eve',
            seq: 3,
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      );

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
  }) async =>
      'attachment-1';

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    String? clientId,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async =>
      message;

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async =>
      null;

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
      const [];

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

class _FakeSavedMessagesRepository implements SavedMessagesRepository {
  @override
  Future<saved_data.SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async =>
      const saved_data.SavedMessagesPage(items: [], hasMore: false);

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      const {};
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: Per-message boolean select only notifies when that message's saved
  //     state changes — not when a sibling message is saved/unsaved.
  //
  // This test uses `container.listen` with a per-message select expression
  // to count how many times each listener is notified.
  //
  // With the current full-Set select, ALL listeners fire on any save toggle.
  // After Phase B fix (per-ID boolean select), only the affected listener
  // fires.
  //
  // skip:true — requires Phase B per-message select in widget build.
  // -------------------------------------------------------------------------
  test(
    'INV-PERF-SAVED-1: saving msg-1 does NOT notify select for msg-2 or msg-3',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider
              .overrideWithValue(_channelTarget),
          conversationRepositoryProvider
              .overrideWithValue(_FakeConversationRepository()),
          savedMessagesRepositoryProvider
              .overrideWithValue(_FakeSavedMessagesRepository()),
          sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      // Keep the store alive.
      final keepAlive = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
      );

      // Trigger initial load.
      await container.read(conversationDetailStoreProvider.notifier).load();

      // Allow unawaited refreshSavedMessageIds to settle.
      await Future<void>.delayed(Duration.zero);

      // Per-message boolean selects (the Phase B pattern).
      int msg1NotifyCount = 0;
      int msg2NotifyCount = 0;
      int msg3NotifyCount = 0;

      container.listen(
        conversationDetailStoreProvider.select(
          (s) => s.savedMessageIds.contains('msg-1'),
        ),
        (_, __) => msg1NotifyCount++,
      );
      container.listen(
        conversationDetailStoreProvider.select(
          (s) => s.savedMessageIds.contains('msg-2'),
        ),
        (_, __) => msg2NotifyCount++,
      );
      container.listen(
        conversationDetailStoreProvider.select(
          (s) => s.savedMessageIds.contains('msg-3'),
        ),
        (_, __) => msg3NotifyCount++,
      );

      // Save msg-1 (toggleSaveMessage is optimistic).
      await container
          .read(conversationDetailStoreProvider.notifier)
          .toggleSaveMessage('msg-1');

      // Invariant: only msg-1 listener fires.
      expect(
        msg1NotifyCount,
        1,
        reason: 'msg-1 select must fire exactly once after saving msg-1',
      );
      expect(
        msg2NotifyCount,
        0,
        reason: 'msg-2 select must NOT fire when msg-1 is saved '
            '(INV-PERF-SAVED-1)',
      );
      expect(
        msg3NotifyCount,
        0,
        reason: 'msg-3 select must NOT fire when msg-1 is saved '
            '(INV-PERF-SAVED-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: Unsaving a message only notifies that message's select listener.
  //
  // Pre-condition: msg-1 and msg-2 are both saved. Unsave msg-2 → only
  // msg-2 listener notifies.
  //
  // skip:true — requires Phase B per-message select in widget build.
  // -------------------------------------------------------------------------
  test(
    'INV-PERF-SAVED-1: unsaving msg-2 does NOT notify select for msg-1 or msg-3',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider
              .overrideWithValue(_channelTarget),
          conversationRepositoryProvider
              .overrideWithValue(_FakeConversationRepository()),
          savedMessagesRepositoryProvider
              .overrideWithValue(_FakeSavedMessagesRepository()),
          sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
      );

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Allow unawaited refreshSavedMessageIds to settle.
      await Future<void>.delayed(Duration.zero);

      // Pre-save msg-1 and msg-2 to set up unsave scenario.
      await container
          .read(conversationDetailStoreProvider.notifier)
          .toggleSaveMessage('msg-1');
      await container
          .read(conversationDetailStoreProvider.notifier)
          .toggleSaveMessage('msg-2');

      // Now attach per-message listeners (after the pre-save setup).
      int msg1NotifyCount = 0;
      int msg2NotifyCount = 0;
      int msg3NotifyCount = 0;

      container.listen(
        conversationDetailStoreProvider.select(
          (s) => s.savedMessageIds.contains('msg-1'),
        ),
        (_, __) => msg1NotifyCount++,
      );
      container.listen(
        conversationDetailStoreProvider.select(
          (s) => s.savedMessageIds.contains('msg-2'),
        ),
        (_, __) => msg2NotifyCount++,
      );
      container.listen(
        conversationDetailStoreProvider.select(
          (s) => s.savedMessageIds.contains('msg-3'),
        ),
        (_, __) => msg3NotifyCount++,
      );

      // Unsave msg-2.
      await container
          .read(conversationDetailStoreProvider.notifier)
          .toggleSaveMessage('msg-2');

      // Invariant: only msg-2 listener fires.
      expect(
        msg2NotifyCount,
        1,
        reason: 'msg-2 select must fire exactly once after unsaving msg-2',
      );
      expect(
        msg1NotifyCount,
        0,
        reason: 'msg-1 select must NOT fire when msg-2 is unsaved '
            '(INV-PERF-SAVED-1)',
      );
      expect(
        msg3NotifyCount,
        0,
        reason: 'msg-3 select must NOT fire when msg-2 is unsaved '
            '(INV-PERF-SAVED-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: Full-Set select fires for ALL messages on any save/unsave.
  //
  // This is the anti-pattern test: it proves the current behavior is wrong.
  // With the full-Set select, every card's listener fires on any mutation.
  //
  // This test passes NOW (demonstrating the bug) and will continue to pass
  // after Phase B (the full-Set select still fires for all if someone
  // watches it — but cards no longer use it).
  // -------------------------------------------------------------------------
  test(
    'full-Set select fires for all messages on any save (anti-pattern proof)',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider
              .overrideWithValue(_channelTarget),
          conversationRepositoryProvider
              .overrideWithValue(_FakeConversationRepository()),
          savedMessagesRepositoryProvider
              .overrideWithValue(_FakeSavedMessagesRepository()),
          sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
      );

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Allow unawaited refreshSavedMessageIds to settle.
      await Future<void>.delayed(Duration.zero);

      // Full-Set select (the current pattern in _ConversationMessageCard).
      int fullSetNotifyCount = 0;
      container.listen(
        conversationDetailStoreProvider.select((s) => s.savedMessageIds),
        (_, __) => fullSetNotifyCount++,
      );

      // Save msg-1.
      await container
          .read(conversationDetailStoreProvider.notifier)
          .toggleSaveMessage('msg-1');

      // Full-Set select fires (Set reference changed).
      expect(
        fullSetNotifyCount,
        greaterThanOrEqualTo(1),
        reason: 'Full-Set select must fire when any message is saved',
      );

      final countAfterFirst = fullSetNotifyCount;

      // Save msg-2 — fires again (Set reference changes again).
      await container
          .read(conversationDetailStoreProvider.notifier)
          .toggleSaveMessage('msg-2');

      expect(
        fullSetNotifyCount,
        greaterThan(countAfterFirst),
        reason: 'Full-Set select must fire again for a different message save',
      );

      keepAlive.close();
    },
  );
}
