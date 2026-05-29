// =============================================================================
// Scan #45 P2 — Load-bearing tests for generic catch + disposed guard
//
// Proves:
// T1: load() — repo throws non-AppFailure → state transitions to failure
//     (not stuck in loading). Reverting the catch → test RED.
// T2: refresh() — repo throws non-AppFailure → isRefreshing cleared +
//     UnknownFailure overlayed. Reverting the catch → test RED.
// T3: send() — repo throws non-AppFailure → pending message transitions to
//     failed (not stuck sending). Reverting the catch → test RED.
// T4: retrySend() — repo throws non-AppFailure → pending message transitions
//     to failed. Reverting the catch → test RED.
// T5: send() — dispose before failure resumes → no StateError (guard value).
// T6: retrySend() — dispose before failure resumes → no StateError.
// =============================================================================

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  final messages = [
    ConversationMessageSummary(
      id: 'msg-1',
      content: 'Hello',
      createdAt: DateTime.utc(2026, 5, 20),
      senderType: 'human',
      messageType: 'message',
      seq: 1,
    ),
  ];

  // ===========================================================================
  // T1: load() — non-AppFailure → failure state (not stuck loading)
  // ===========================================================================
  test(
    'Scan #45: load() with non-AppFailure transitions to failure state',
    () async {
      final repo = _ThrowingRepo(
        loadError: const FormatException('bad JSON'),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      final state = container.read(conversationDetailStoreProvider);
      expect(
        state.status,
        ConversationDetailStatus.failure,
        reason: 'Scan #45: load() must land in failure when repo throws '
            'non-AppFailure. Removing the generic catch leaves status stuck '
            'in loading → RED.',
      );
      expect(state.failure, isA<UnknownFailure>());
      expect(
        state.failure?.causeType,
        'FormatException',
        reason: 'causeType must capture the error runtime type',
      );
    },
  );

  // ===========================================================================
  // T2: refresh() — non-AppFailure → isRefreshing cleared + failure overlayed
  // ===========================================================================
  test(
    'Scan #45: refresh() with non-AppFailure clears isRefreshing and overlays failure',
    () async {
      // First: load successfully so refresh() doesn't fall back to load().
      final repo = _ThrowingRepo(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: messages,
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
      expect(
        container.read(conversationDetailStoreProvider).status,
        ConversationDetailStatus.success,
      );

      // Now make the repo throw non-AppFailure on next load.
      repo.loadError = StateError('provider disposed');

      await container.read(conversationDetailStoreProvider.notifier).refresh();

      final state = container.read(conversationDetailStoreProvider);
      expect(
        state.isRefreshing,
        isFalse,
        reason: 'Scan #45: refresh() must clear isRefreshing when repo throws '
            'non-AppFailure. Removing the generic catch leaves isRefreshing '
            'stuck true → RED.',
      );
      expect(state.failure, isA<UnknownFailure>());
      expect(state.failure?.causeType, 'StateError');
      // Messages should be preserved (SWR: stale data visible).
      expect(state.messages, isNotEmpty);
    },
  );

  // ===========================================================================
  // T3: send() — non-AppFailure → pending message transitions to failed
  // ===========================================================================
  test(
    'Scan #45: send() with non-AppFailure transitions pending to failed',
    () async {
      final repo = _ThrowingRepo(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: messages,
          historyLimited: false,
          hasOlder: false,
        ),
        sendError: const FormatException('unexpected send error'),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // Load to get into success state.
      await container.read(conversationDetailStoreProvider.notifier).load();

      // Set draft and send.
      container
          .read(conversationDetailStoreProvider.notifier)
          .updateDraft('hi');
      await container.read(conversationDetailStoreProvider.notifier).send();

      final state = container.read(conversationDetailStoreProvider);
      final pending = state.pendingMessages.firstOrNull;
      expect(
        pending,
        isNotNull,
        reason: 'Pending message must exist after failed send',
      );
      expect(
        pending!.status,
        MessageSendStatus.failed,
        reason: 'Scan #45: send() must transition pending to failed when repo '
            'throws non-AppFailure. Removing the generic catch leaves pending '
            'stuck in sending → RED.',
      );
    },
  );

  // ===========================================================================
  // T4: retrySend() — non-AppFailure → pending message transitions to failed
  // ===========================================================================
  test(
    'Scan #45: retrySend() with non-AppFailure transitions pending to failed',
    () async {
      // Use a completer-controlled repo: first send fails with AppFailure to
      // get a failed pending, then retrySend throws non-AppFailure.
      final repo = _ThrowingRepo(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: messages,
          historyLimited: false,
          hasOlder: false,
        ),
        sendError: const ValidationFailure(message: 'invalid'),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Send — fails with non-retryable AppFailure → .failed.
      container
          .read(conversationDetailStoreProvider.notifier)
          .updateDraft('yo');
      await container.read(conversationDetailStoreProvider.notifier).send();

      var state = container.read(conversationDetailStoreProvider);
      final localId = state.pendingMessages.first.localId;
      expect(state.pendingMessages.first.status, MessageSendStatus.failed);

      // Now switch to non-AppFailure error for retry.
      repo.sendError = const FormatException('unexpected retry error');
      await container
          .read(conversationDetailStoreProvider.notifier)
          .retrySend(localId);

      state = container.read(conversationDetailStoreProvider);
      final retried =
          state.pendingMessages.where((m) => m.localId == localId).firstOrNull;
      expect(
        retried,
        isNotNull,
        reason: 'Pending must still exist after failed retry',
      );
      expect(
        retried!.status,
        MessageSendStatus.failed,
        reason: 'Scan #45: retrySend() must transition pending to failed when '
            'repo throws non-AppFailure. Removing the generic catch leaves '
            'pending stuck in sending → RED.',
      );
    },
  );

  // ===========================================================================
  // T5: send() — dispose before failure resumes → no StateError
  // ===========================================================================
  test(
    'Scan #45: send() — dispose before failure resumes causes no StateError',
    () async {
      final sendCompleter = Completer<ConversationMessageSummary>();
      final repo = _ThrowingRepo(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: messages,
          historyLimited: false,
          hasOlder: false,
        ),
        sendCompleter: sendCompleter,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await container.read(conversationDetailStoreProvider.notifier).load();

      container
          .read(conversationDetailStoreProvider.notifier)
          .updateDraft('hi');
      // Start send — it will await the completer.
      final sendFuture =
          container.read(conversationDetailStoreProvider.notifier).send();

      // Dispose before the send completes.
      container.dispose();

      // Complete with failure — the disposed guard prevents StateError.
      sendCompleter
          .completeError(const NetworkFailure(message: 'after dispose'));

      // If the guard is removed, this would throw StateError from ref.read().
      // With the guard, it completes silently.
      await expectLater(sendFuture, completes);
    },
  );

  // ===========================================================================
  // T6: retrySend() — dispose before failure resumes → no StateError
  // ===========================================================================
  test(
    'Scan #45: retrySend() — dispose before failure resumes causes no StateError',
    () async {
      // First send to create a failed pending message.
      final repo = _ThrowingRepo(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: messages,
          historyLimited: false,
          hasOlder: false,
        ),
        sendError: const ValidationFailure(message: 'invalid'),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await container.read(conversationDetailStoreProvider.notifier).load();

      container
          .read(conversationDetailStoreProvider.notifier)
          .updateDraft('yo');
      await container.read(conversationDetailStoreProvider.notifier).send();

      final localId = container
          .read(conversationDetailStoreProvider)
          .pendingMessages
          .first
          .localId;

      // Now set up a completer for the retry.
      final retryCompleter = Completer<ConversationMessageSummary>();
      repo.sendError = null;
      repo.sendCompleter = retryCompleter;

      final retryFuture = container
          .read(conversationDetailStoreProvider.notifier)
          .retrySend(localId);

      // Dispose before retry completes.
      container.dispose();

      // Complete with failure — the disposed guard prevents StateError.
      retryCompleter
          .completeError(const NetworkFailure(message: 'after dispose'));

      // If the guard is removed, this would throw StateError from ref.read().
      await expectLater(retryFuture, completes);
    },
  );
}

// =============================================================================
// Fakes
// =============================================================================

/// Repository that throws configurable errors.
class _ThrowingRepo implements ConversationRepository {
  _ThrowingRepo({
    this.snapshot,
    this.loadError,
    this.sendError,
    this.sendCompleter,
  });

  ConversationDetailSnapshot? snapshot;
  Object? loadError;
  Object? sendError;
  Completer<ConversationMessageSummary>? sendCompleter;

  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    if (loadError != null) throw loadError!;
    return snapshot!;
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
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    if (sendCompleter != null) return sendCompleter!.future;
    if (sendError != null) throw sendError!;
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
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    return 'att-1';
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
