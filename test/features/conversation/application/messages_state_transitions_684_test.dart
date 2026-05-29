// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, unused_element_parameter

// =============================================================================
// #684 — Messages send/edit/delete state transition tests
//
// Tests the state machine for:
// 1. Send: composing → sending → sent (captures intermediate state)
// 2. Edit: idle → optimistic update → persisted (success) or reverted (failure)
// 3. Delete: visible → isDeleted=true → persisted (success) or reverted (failure)
//
// Focus: state machine only (no widget tests). Uses Completers to observe
// intermediate states during async operations.
// =============================================================================

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
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

  final baseMessages = [
    ConversationMessageSummary(
      id: 'msg-1',
      content: 'Hello world',
      createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: 1,
    ),
    ConversationMessageSummary(
      id: 'msg-2',
      content: 'Second message',
      createdAt: DateTime.parse('2026-04-19T15:01:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: 2,
    ),
  ];

  ConnectivityService onlineConnectivity() {
    final c = StreamController<ConnectivityStatus>.broadcast();
    return ConnectivityService.withInitialStatus(
      ConnectivityStatus.online,
      controller: c,
    );
  }

  group('#684 — Send state transitions', () {
    test('send transitions through sending → sent', () async {
      final sendCompleter = Completer<ConversationMessageSummary>();
      final sentMessage = ConversationMessageSummary(
        id: 'msg-3',
        content: 'New message',
        createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 3,
      );

      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: baseMessages,
          historyLimited: false,
          hasOlder: false,
        ),
        sendCompleter: sendCompleter,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          connectivityServiceProvider.overrideWithValue(onlineConnectivity()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      // Compose
      notifier.updateDraft('New message');
      expect(
        container.read(conversationDetailStoreProvider).draft,
        'New message',
      );

      // Start send (don't await — observe intermediate state)
      final sendFuture = notifier.send();

      // Allow microtask to fire (optimistic insert)
      await Future<void>.value();

      // INTERMEDIATE STATE: pending message exists with 'sending' status
      final midState = container.read(conversationDetailStoreProvider);
      expect(midState.draft, isEmpty, reason: 'Draft cleared on send start');
      expect(midState.pendingMessages, hasLength(1));
      expect(
        midState.pendingMessages.first.status,
        MessageSendStatus.sending,
        reason: 'Intermediate state: message should be in sending status',
      );
      expect(midState.pendingMessages.first.content, 'New message');

      // Complete the send
      sendCompleter.complete(sentMessage);
      await sendFuture;

      // FINAL STATE: pending message transitions to 'sent'
      final finalState = container.read(conversationDetailStoreProvider);
      expect(finalState.pendingMessages, hasLength(1));
      expect(
        finalState.pendingMessages.first.status,
        MessageSendStatus.sent,
        reason: 'Final state: message should be in sent status',
      );
    });

    test('send transitions to failed on non-retryable error', () async {
      const failure = NotFoundFailure(message: 'Channel not found.');
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: baseMessages,
          historyLimited: false,
          hasOlder: false,
        ),
        sendFailure: failure,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          connectivityServiceProvider.overrideWithValue(onlineConnectivity()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      notifier.updateDraft('Will fail');
      await notifier.send();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.pendingMessages, hasLength(1));
      expect(
        state.pendingMessages.first.status,
        MessageSendStatus.failed,
        reason: 'Non-retryable failure → failed status',
      );
    });
  });

  group('#684 — Edit state transitions', () {
    test('editMessage applies optimistic update then persists on success',
        () async {
      final editCompleter = Completer<void>();
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: baseMessages,
          historyLimited: false,
          hasOlder: false,
        ),
        editCompleter: editCompleter,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Start edit (don't await — observe intermediate state)
      final editFuture = container
          .read(conversationDetailStoreProvider.notifier)
          .editMessage('msg-1', 'Updated content');

      // Allow microtask to fire (optimistic update)
      await Future<void>.value();

      // INTERMEDIATE STATE: message content updated optimistically
      final midState = container.read(conversationDetailStoreProvider);
      final editedMsg = midState.messages.firstWhere((m) => m.id == 'msg-1');
      expect(
        editedMsg.content,
        'Updated content',
        reason: 'Optimistic update: message should show new content',
      );

      // Complete the edit
      editCompleter.complete();
      await editFuture;

      // FINAL STATE: content still updated (persisted)
      final finalState = container.read(conversationDetailStoreProvider);
      final persistedMsg =
          finalState.messages.firstWhere((m) => m.id == 'msg-1');
      expect(
        persistedMsg.content,
        'Updated content',
        reason: 'After success: content persisted',
      );
    });

    test('editMessage reverts optimistic update on failure', () async {
      const failure = ServerFailure(
        message: 'Forbidden.',
        statusCode: 403,
      );
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: baseMessages,
          historyLimited: false,
          hasOlder: false,
        ),
        editFailure: failure,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Edit should throw and revert
      await expectLater(
        container
            .read(conversationDetailStoreProvider.notifier)
            .editMessage('msg-1', 'Forbidden edit'),
        throwsA(isA<ServerFailure>()),
      );

      // STATE: reverted to original content
      final state = container.read(conversationDetailStoreProvider);
      final msg = state.messages.firstWhere((m) => m.id == 'msg-1');
      expect(
        msg.content,
        'Hello world',
        reason: 'After failure: content reverted to original',
      );
    });
  });

  group('#684 — Delete state transitions', () {
    test('deleteMessage applies optimistic isDeleted then persists', () async {
      final deleteCompleter = Completer<void>();
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: baseMessages,
          historyLimited: false,
          hasOlder: false,
        ),
        deleteCompleter: deleteCompleter,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Start delete (don't await — observe intermediate state)
      final deleteFuture = container
          .read(conversationDetailStoreProvider.notifier)
          .deleteMessage('msg-1');

      // Allow microtask to fire (optimistic update)
      await Future<void>.value();

      // INTERMEDIATE STATE: message marked as deleted optimistically
      final midState = container.read(conversationDetailStoreProvider);
      final deletedMsg = midState.messages.firstWhere((m) => m.id == 'msg-1');
      expect(
        deletedMsg.isDeleted,
        isTrue,
        reason: 'Optimistic update: message should be marked deleted',
      );
      // Other messages unaffected
      final otherMsg = midState.messages.firstWhere((m) => m.id == 'msg-2');
      expect(otherMsg.isDeleted, isFalse);

      // Complete the delete
      deleteCompleter.complete();
      await deleteFuture;

      // FINAL STATE: still deleted (persisted)
      final finalState = container.read(conversationDetailStoreProvider);
      final persistedMsg =
          finalState.messages.firstWhere((m) => m.id == 'msg-1');
      expect(
        persistedMsg.isDeleted,
        isTrue,
        reason: 'After success: deletion persisted',
      );
    });

    test('deleteMessage reverts optimistic isDeleted on failure', () async {
      const failure = ServerFailure(
        message: 'Forbidden.',
        statusCode: 403,
      );
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: baseMessages,
          historyLimited: false,
          hasOlder: false,
        ),
        deleteFailure: failure,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      await expectLater(
        container
            .read(conversationDetailStoreProvider.notifier)
            .deleteMessage('msg-1'),
        throwsA(isA<ServerFailure>()),
      );

      // STATE: reverted — message no longer marked deleted
      final state = container.read(conversationDetailStoreProvider);
      final msg = state.messages.firstWhere((m) => m.id == 'msg-1');
      expect(
        msg.isDeleted,
        isFalse,
        reason: 'After failure: isDeleted reverted to false',
      );
    });
  });
}

// =============================================================================
// Fake repository with Completers for observing intermediate states
// =============================================================================

class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _FakeConversationRepository({
    required this.snapshot,
    this.sentMessage,
    this.sendFailure,
    this.sendCompleter,
    this.editFailure,
    this.editCompleter,
    this.deleteFailure,
    this.deleteCompleter,
  });

  final ConversationDetailSnapshot snapshot;
  final ConversationMessageSummary? sentMessage;
  final AppFailure? sendFailure;
  final Completer<ConversationMessageSummary>? sendCompleter;
  final AppFailure? editFailure;
  final Completer<void>? editCompleter;
  final AppFailure? deleteFailure;
  final Completer<void>? deleteCompleter;

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
    if (sendFailure != null) throw sendFailure!;
    if (sendCompleter != null) return sendCompleter!.future;
    return sentMessage!;
  }

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
  }) async {
    if (editCompleter != null) {
      await editCompleter!.future;
    }
    if (editFailure != null) throw editFailure!;
  }

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    if (deleteCompleter != null) {
      await deleteCompleter!.future;
    }
    if (deleteFailure != null) throw deleteFailure!;
  }

  @override
  Future<void> removeStoredMessage(
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
}
