// =============================================================================
// #769 — O(n)→O(1) Message Deletion Lookup
//
// Verifies:
// A. _handleMessageDeleted uses _messageIndexMap for O(1) lookup
// B. Index consistency after multiple deletions (head, middle, tail)
// C. Stale index map gracefully handles concurrent list mutations
// D. Sequential deletes maintain warm cache (no O(n) rebuild per delete)
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'channel-1',
    ),
  );

  /// Generate N messages for stress tests.
  List<ConversationMessageSummary> generateMessages(int count) {
    return List.generate(
      count,
      (i) => ConversationMessageSummary(
        id: 'msg-$i',
        content: 'Message $i',
        createdAt: DateTime(2026, 5, 22, 10, i),
        senderType: 'human',
        messageType: 'message',
        seq: i + 1,
      ),
    );
  }

  group('#769 — O(1) message deletion lookup', () {
    test('messageIndexMap returns correct indices for all messages', () async {
      final messages = generateMessages(100);
      final repo = _FakeRepository(messages: messages);
      final ingress = RealtimeReductionIngress();

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      final store = container.read(conversationDetailStoreProvider.notifier);
      final indexMap = store.messageIndexMapForTesting;

      // Every message should have a correct index entry.
      expect(indexMap.length, 100);
      for (var i = 0; i < 100; i++) {
        expect(indexMap['msg-$i'], i, reason: 'msg-$i should be at index $i');
      }
    });

    test(
        'deletion of message in 100+ item list uses index map (not linear scan)',
        () async {
      final messages = generateMessages(150);
      final repo = _FakeRepository(messages: messages);
      final ingress = RealtimeReductionIngress();

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Warm the index map before deletion.
      final store = container.read(conversationDetailStoreProvider.notifier);
      expect(store.messageIndexMapForTesting['msg-75'], 75);

      // Delete message in the middle via realtime event.
      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:deleted',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 5, 22),
          seq: 200,
          payload: {
            'id': 'msg-75',
            'channelId': target.conversationId,
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      // Verify the message is marked as deleted.
      final state = container.read(conversationDetailStoreProvider);
      final deletedMsg = state.messages[75];
      expect(deletedMsg.id, 'msg-75');
      expect(deletedMsg.isDeleted, isTrue,
          reason: 'Message at index 75 should be marked deleted');

      // Other messages remain unchanged.
      expect(state.messages[74].isDeleted, isFalse);
      expect(state.messages[76].isDeleted, isFalse);
      expect(state.messages.length, 150,
          reason: 'Message list length unchanged (soft delete)');
    });

    test('multiple deletions (head, middle, tail) maintain consistency',
        () async {
      final messages = generateMessages(50);
      final repo = _FakeRepository(messages: messages);
      final ingress = RealtimeReductionIngress();

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Delete head (index 0).
      ingress.accept(_deleteEvent('msg-0', target, seq: 200));
      await Future<void>.delayed(Duration.zero);

      // Delete tail (index 49).
      ingress.accept(_deleteEvent('msg-49', target, seq: 201));
      await Future<void>.delayed(Duration.zero);

      // Delete middle (index 25).
      ingress.accept(_deleteEvent('msg-25', target, seq: 202));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[0].isDeleted, isTrue, reason: 'Head deleted');
      expect(state.messages[49].isDeleted, isTrue, reason: 'Tail deleted');
      expect(state.messages[25].isDeleted, isTrue, reason: 'Middle deleted');

      // Non-deleted messages remain intact.
      expect(state.messages[1].isDeleted, isFalse);
      expect(state.messages[24].isDeleted, isFalse);
      expect(state.messages[26].isDeleted, isFalse);
      expect(state.messages[48].isDeleted, isFalse);
      expect(state.messages.length, 50);
    });

    test('sequential deletes keep index map cache warm (no O(n) rebuild)',
        () async {
      final messages = generateMessages(100);
      final repo = _FakeRepository(messages: messages);
      final ingress = RealtimeReductionIngress();

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      final store = container.read(conversationDetailStoreProvider.notifier);

      // Warm the cache by accessing the index map.
      expect(store.messageIndexMapForTesting.length, 100);
      expect(store.isMessageIndexMapCacheWarm, isTrue);

      // Delete first message.
      ingress.accept(_deleteEvent('msg-10', target, seq: 200));
      await Future<void>.delayed(Duration.zero);

      // Cache must still be warm after delete (no rebuild needed).
      expect(store.isMessageIndexMapCacheWarm, isTrue,
          reason: 'Soft-delete preserves indices — cache should stay warm');

      // Delete second message — should also keep cache warm.
      ingress.accept(_deleteEvent('msg-50', target, seq: 201));
      await Future<void>.delayed(Duration.zero);

      expect(store.isMessageIndexMapCacheWarm, isTrue,
          reason: 'Sequential deletes must not invalidate the index map cache');

      // Delete third message — still warm.
      ingress.accept(_deleteEvent('msg-99', target, seq: 202));
      await Future<void>.delayed(Duration.zero);

      expect(store.isMessageIndexMapCacheWarm, isTrue,
          reason: 'Third sequential delete keeps cache warm');

      // Verify correctness — all three deleted.
      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[10].isDeleted, isTrue);
      expect(state.messages[50].isDeleted, isTrue);
      expect(state.messages[99].isDeleted, isTrue);
    });

    test('deletion of already-deleted message is no-op', () async {
      final messages = generateMessages(10);
      final repo = _FakeRepository(messages: messages);
      final ingress = RealtimeReductionIngress();

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Delete message 5.
      ingress.accept(_deleteEvent('msg-5', target, seq: 200));
      await Future<void>.delayed(Duration.zero);
      final stateAfterFirst = container.read(conversationDetailStoreProvider);
      expect(stateAfterFirst.messages[5].isDeleted, isTrue);

      // Delete same message again — should be no-op.
      ingress.accept(_deleteEvent('msg-5', target, seq: 201));
      await Future<void>.delayed(Duration.zero);
      final stateAfterSecond = container.read(conversationDetailStoreProvider);

      // State should be identical (same list identity since no mutation).
      expect(identical(stateAfterFirst.messages, stateAfterSecond.messages),
          isTrue,
          reason:
              'Re-deleting already-deleted message should not mutate state');
    });

    test('deletion of unknown message ID is no-op', () async {
      final messages = generateMessages(10);
      final repo = _FakeRepository(messages: messages);
      final ingress = RealtimeReductionIngress();

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      final stateBefore = container.read(conversationDetailStoreProvider);

      // Delete a non-existent message.
      ingress.accept(_deleteEvent('msg-999', target));
      await Future<void>.delayed(Duration.zero);
      final stateAfter = container.read(conversationDetailStoreProvider);

      // State unchanged.
      expect(identical(stateBefore.messages, stateAfter.messages), isTrue,
          reason: 'Unknown message ID should not mutate state');
    });

    test('index map invalidates correctly after message append', () async {
      final messages = generateMessages(5);
      final repo = _FakeRepository(messages: messages);
      final ingress = RealtimeReductionIngress();

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      final store = container.read(conversationDetailStoreProvider.notifier);

      // Warm the cache.
      expect(store.messageIndexMapForTesting.length, 5);

      // Add a new message via realtime.
      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 5, 22),
          seq: 10,
          payload: {
            'id': 'msg-new',
            'channelId': target.conversationId,
            'content': 'New message',
            'createdAt': '2026-05-22T11:00:00Z',
            'senderType': 'human',
            'messageType': 'message',
            'senderId': 'user-1',
            'seq': 10,
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      // Index map should now include the new message.
      final newMap = store.messageIndexMapForTesting;
      expect(newMap.containsKey('msg-new'), isTrue);
      expect(newMap.length, 6);

      // Delete the new message — should work with updated map.
      ingress.accept(_deleteEvent('msg-new', target));
      await Future<void>.delayed(Duration.zero);
      final state = container.read(conversationDetailStoreProvider);
      final newMsg = state.messages.firstWhere((m) => m.id == 'msg-new');
      expect(newMsg.isDeleted, isTrue);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RealtimeEventEnvelope _deleteEvent(
    String messageId, ConversationDetailTarget target,
    {int seq = 200}) {
  return RealtimeEventEnvelope(
    eventType: 'message:deleted',
    scopeKey: RealtimeEventEnvelope.globalScopeKey,
    receivedAt: DateTime(2026, 5, 22),
    seq: seq,
    payload: {
      'id': messageId,
      'channelId': target.conversationId,
    },
  );
}

class _FakeRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _FakeRepository({required this.messages});
  final List<ConversationMessageSummary> messages;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return ConversationDetailSnapshot(
      target: target,
      title: '#channel-1',
      messages: messages,
      historyLimited: false,
      hasOlder: false,
    );
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
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    dynamic cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    dynamic attachment, {
    void Function(int sent, int total)? onSendProgress,
    dynamic cancelToken,
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
