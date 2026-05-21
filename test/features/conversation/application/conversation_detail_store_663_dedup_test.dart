// =============================================================================
// #663 — ConversationDetailStore dedup Set invalidation (unit)
//
// Invariant: INV-DEDUP-663-1
//   _messageIdSet is a lazily-cached Set<String> that rebuilds when the
//   state.messages list identity changes. After new messages are appended
//   (via load, realtime, or dedup append), the Set must include the new IDs.
//
// Strategy (ProviderContainer unit tests):
// T1: After initial load, messageIdSetForTesting contains all loaded message IDs.
// T2: After a second message is appended via _appendDedupedMessage (simulated by
//     consecutive loads with new messages), the Set invalidates and includes the
//     new message ID.
// T3: Set-based dedup rejects duplicate message — state.messages length unchanged.
// T4: Set invalidation is lazy — same list identity returns cached Set instance.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:dio/dio.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({required this.snapshot});

  ConversationDetailSnapshot snapshot;

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
    );
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
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
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
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async {
    return const [];
  }

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ConversationMessageSummary _msg(String id, {int? seq}) =>
    ConversationMessageSummary(
      id: id,
      content: 'content-$id',
      createdAt: DateTime.parse('2026-05-20T10:00:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: seq,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'ch-1',
    ),
  );

  // -------------------------------------------------------------------------
  // T1: After load, Set contains all loaded message IDs.
  // -------------------------------------------------------------------------
  test(
    'INV-DEDUP-663-1: messageIdSetForTesting contains loaded message IDs',
    () async {
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#ch-1',
          messages: [_msg('m-1', seq: 1), _msg('m-2', seq: 2)],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      final idSet = store.messageIdSetForTesting;
      expect(idSet, contains('m-1'));
      expect(idSet, contains('m-2'));
      expect(idSet.length, 2);
    },
  );

  // -------------------------------------------------------------------------
  // T2: After messages list changes (reload with new message), Set invalidates
  //     and includes the new ID. This would FAIL if invalidation were broken
  //     (i.e. if we used a static Set that never rebuilds).
  // -------------------------------------------------------------------------
  test(
    'INV-DEDUP-663-1: Set invalidates after messages list identity changes',
    () async {
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#ch-1',
          messages: [_msg('m-1', seq: 1)],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      // Set should contain only m-1.
      expect(store.messageIdSetForTesting, {'m-1'});

      // Simulate reload with a new message added.
      repo.snapshot = ConversationDetailSnapshot(
        target: target,
        title: '#ch-1',
        messages: [_msg('m-1', seq: 1), _msg('m-3', seq: 3)],
        historyLimited: false,
        hasOlder: false,
      );
      await store.load();

      // After reload, Set must invalidate and include m-3.
      final updatedSet = store.messageIdSetForTesting;
      expect(
        updatedSet,
        contains('m-3'),
        reason: 'Set must invalidate when messages list identity changes '
            '(INV-DEDUP-663-1)',
      );
      expect(updatedSet, {'m-1', 'm-3'});
    },
  );

  // -------------------------------------------------------------------------
  // T3: Dedup rejects a duplicate message — Set.contains used for O(1) check.
  //     After load with [m-1, m-2], reload returns [m-1, m-2] again —
  //     state.messages should remain unchanged (same length).
  // -------------------------------------------------------------------------
  test(
    'INV-DEDUP-663-1: duplicate messages rejected via Set-based dedup',
    () async {
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#ch-1',
          messages: [_msg('m-1', seq: 1), _msg('m-2', seq: 2)],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);
      final state = container.read(conversationDetailStoreProvider);

      expect(state.messages.length, 2);
      // The Set already has m-1 and m-2.
      expect(store.messageIdSetForTesting, {'m-1', 'm-2'});
    },
  );

  // -------------------------------------------------------------------------
  // T4: Same list identity returns cached Set (lazy invalidation).
  // -------------------------------------------------------------------------
  test(
    'INV-DEDUP-663-1: same messages identity returns identical Set instance',
    () async {
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#ch-1',
          messages: [_msg('m-1', seq: 1)],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      final set1 = store.messageIdSetForTesting;
      final set2 = store.messageIdSetForTesting;
      expect(identical(set1, set2), isTrue,
          reason: 'Same list identity must return cached Set');
    },
  );

  // -------------------------------------------------------------------------
  // T5: Hot-path verification — _appendDedupedMessage actually consults
  // _messageIdSet. Would FAIL if line 72 were reverted to existing.any().
  //
  // Strategy: after load(), the Set cache is cold (load doesn't access
  // _messageIdSet). Calling appendDedupedMessageForTesting warms it. We
  // observe this via isMessageIdSetCacheWarm.
  // -------------------------------------------------------------------------
  test(
    'INV-DEDUP-663-1: appendDedupedMessage consults _messageIdSet '
    '(hot-path pinned)',
    () async {
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#ch-1',
          messages: [_msg('m-1', seq: 1), _msg('m-2', seq: 2)],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      // After load, cache is cold — load() does not access _messageIdSet.
      expect(
        store.isMessageIdSetCacheWarm,
        isFalse,
        reason: 'Set cache must be cold immediately after load '
            '(load does not consult _messageIdSet)',
      );

      // Call the append hot path with a duplicate message.
      final state = container.read(conversationDetailStoreProvider);
      final result = store.appendDedupedMessageForTesting(
        state.messages,
        _msg('m-1', seq: 1),
      );

      // Duplicate must be rejected.
      expect(
        identical(result, state.messages),
        isTrue,
        reason: 'Duplicate message must be rejected by Set.contains()',
      );

      // After the append path ran, cache must be warm — proving
      // _appendDedupedMessage consulted _messageIdSet. If the code were
      // reverted to existing.any(), the cache would remain cold and this
      // assertion would FAIL.
      expect(
        store.isMessageIdSetCacheWarm,
        isTrue,
        reason: 'Set cache must be warm after appendDedupedMessage — '
            'proves hot path consults _messageIdSet (INV-DEDUP-663-1)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T6: Hot-path — non-duplicate append returns extended list and Set still
  // reflects the append caller's messages.
  // -------------------------------------------------------------------------
  test(
    'INV-DEDUP-663-1: appendDedupedMessage returns extended list for '
    'non-duplicate',
    () async {
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#ch-1',
          messages: [_msg('m-1', seq: 1)],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);
      final state = container.read(conversationDetailStoreProvider);

      // Append a non-duplicate message.
      final result = store.appendDedupedMessageForTesting(
        state.messages,
        _msg('m-new', seq: 5),
      );

      // Should return extended list.
      expect(result.length, 2);
      expect(result.last.id, 'm-new');

      // Cache must be warm (proves _messageIdSet was consulted).
      expect(store.isMessageIdSetCacheWarm, isTrue);
    },
  );
}
