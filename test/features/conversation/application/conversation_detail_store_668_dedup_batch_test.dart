// =============================================================================
// #668 — Batch dedup path reuses cached Set + PinnedMessagesState ==/hashCode
//
// Fix A Invariant: INV-DEDUP-668
//   _prependDedupedMessages and _appendDedupedMessages reuse the lazily-cached
//   _messageIdSet (introduced in #663) instead of allocating a fresh Set via
//   .map().toSet() on every pagination call.
//
// Fix B Invariant:
//   PinnedMessagesState has correct == and hashCode so that Riverpod can skip
//   downstream rebuilds when copyWith produces an equivalent state.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/pinned_messages_store.dart';
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
  ) async =>
      snapshot;

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
      );

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
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
  ) async =>
      const [];

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
      createdAt: DateTime.parse('2026-05-21T10:00:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: seq,
    );

// ---------------------------------------------------------------------------
// Tests — Fix A: Batch dedup path reuses cached Set
// ---------------------------------------------------------------------------

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'ch-1',
    ),
  );

  group('Fix A: batch dedup reuses cached _messageIdSet', () {
    test(
      'INV-DEDUP-668: _prependDedupedMessages uses cached Set (rejects duplicates)',
      () async {
        final repo = _FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#ch-1',
            messages: [_msg('m-1', seq: 1), _msg('m-2', seq: 2)],
            historyLimited: false,
            hasOlder: true,
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

        // Warm the lazily-cached _messageIdSet by accessing the getter.
        store.messageIdSetForTesting;
        expect(store.isMessageIdSetCacheWarm, isTrue);

        // Prepend with a mix of new and duplicate messages.
        final existing =
            container.read(conversationDetailStoreProvider).messages;
        final result = store.prependDedupedMessagesForTesting(
          existing,
          [_msg('m-0', seq: 0), _msg('m-1', seq: 1)], // m-1 is duplicate
        );

        // Only the new message should be prepended.
        expect(result.length, 3); // m-0 + m-1 + m-2
        expect(result.first.id, 'm-0');
      },
    );

    test(
      'INV-DEDUP-668: _appendDedupedMessages uses cached Set (rejects duplicates)',
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

        // Warm the lazily-cached _messageIdSet by accessing the getter.
        store.messageIdSetForTesting;
        expect(store.isMessageIdSetCacheWarm, isTrue);

        // Append with a mix of new and duplicate messages.
        final existing =
            container.read(conversationDetailStoreProvider).messages;
        final result = store.appendDedupedMessagesForTesting(
          existing,
          [_msg('m-2', seq: 2), _msg('m-3', seq: 3)], // m-2 is duplicate
        );

        // Only the new message should be appended.
        expect(result.length, 3); // m-1 + m-2 + m-3
        expect(result.last.id, 'm-3');
      },
    );

    test(
      'INV-DEDUP-668: batch prepend returns existing list unchanged when all duplicates',
      () async {
        final repo = _FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#ch-1',
            messages: [_msg('m-1', seq: 1), _msg('m-2', seq: 2)],
            historyLimited: false,
            hasOlder: true,
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
        final existing =
            container.read(conversationDetailStoreProvider).messages;

        final result = store.prependDedupedMessagesForTesting(
          existing,
          [_msg('m-1', seq: 1), _msg('m-2', seq: 2)], // all duplicates
        );

        // Returns identical list — no allocation.
        expect(identical(result, existing), isTrue);
      },
    );

    test(
      'INV-DEDUP-668: batch append returns existing list unchanged when all duplicates',
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
        final existing =
            container.read(conversationDetailStoreProvider).messages;

        final result = store.appendDedupedMessagesForTesting(
          existing,
          [_msg('m-1', seq: 1), _msg('m-2', seq: 2)], // all duplicates
        );

        expect(identical(result, existing), isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Tests — Fix B: PinnedMessagesState == / hashCode
  // ---------------------------------------------------------------------------

  group('Fix B: PinnedMessagesState equality', () {
    test('identical states are equal', () {
      const a = PinnedMessagesState();
      const b = PinnedMessagesState();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('states with same messages are equal', () {
      final messages = [_msg('m-1'), _msg('m-2')];
      final a = PinnedMessagesState(
        status: PinnedMessagesStatus.success,
        messages: messages,
      );
      final b = PinnedMessagesState(
        status: PinnedMessagesStatus.success,
        messages: messages,
      );
      expect(a, equals(b));
    });

    test('states with equal but non-identical message lists are equal', () {
      final a = PinnedMessagesState(
        status: PinnedMessagesStatus.success,
        messages: [_msg('m-1')],
      );
      final b = PinnedMessagesState(
        status: PinnedMessagesStatus.success,
        messages: [_msg('m-1')],
      );
      // This relies on ConversationMessageSummary having correct ==.
      // If it doesn't, listEquals will compare element-by-element.
      expect(a == b, isTrue);
    });

    test('different status → not equal', () {
      const a = PinnedMessagesState(status: PinnedMessagesStatus.loading);
      const b = PinnedMessagesState(status: PinnedMessagesStatus.success);
      expect(a, isNot(equals(b)));
    });

    test('different error → not equal', () {
      const a = PinnedMessagesState(
        status: PinnedMessagesStatus.failure,
        error: 'Error A',
      );
      const b = PinnedMessagesState(
        status: PinnedMessagesStatus.failure,
        error: 'Error B',
      );
      expect(a, isNot(equals(b)));
    });

    test('different messages → not equal', () {
      final a = PinnedMessagesState(
        status: PinnedMessagesStatus.success,
        messages: [_msg('m-1')],
      );
      final b = PinnedMessagesState(
        status: PinnedMessagesStatus.success,
        messages: [_msg('m-2')],
      );
      expect(a, isNot(equals(b)));
    });

    test('copyWith producing same values equals original', () {
      final original = PinnedMessagesState(
        status: PinnedMessagesStatus.success,
        messages: [_msg('m-1')],
      );
      final copy = original.copyWith();
      expect(copy, equals(original));
    });

    test('hashCode consistent for equal states', () {
      const a = PinnedMessagesState(
        status: PinnedMessagesStatus.failure,
        error: 'test error',
      );
      const b = PinnedMessagesState(
        status: PinnedMessagesStatus.failure,
        error: 'test error',
      );
      expect(a.hashCode, b.hashCode);
    });
  });
}
