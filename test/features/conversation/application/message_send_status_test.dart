import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

/// TDD tests for message send status feature:
/// - PendingMessage model construction and copyWith
/// - MessageSendStatus enum transitions
/// - Optimistic insert on send (message appears immediately)
/// - Status transitions: sending → sent, sending → failed
/// - Retry logic: failed → sending → sent
/// - Optimistic ordering: pending messages appear after real messages
/// - Failed message persists in state until retried or dismissed
void main() {
  group('PendingMessage model', () {
    test('constructs with required fields and defaults', () {
      final now = DateTime(2026, 5, 6, 10, 0);
      final msg = PendingMessage(
        localId: 'local-1',
        content: 'Hello',
        createdAt: now,
      );

      expect(msg.localId, 'local-1');
      expect(msg.content, 'Hello');
      expect(msg.createdAt, now);
      expect(msg.status, MessageSendStatus.sending);
      expect(msg.attachmentIds, isNull);
      expect(msg.failure, isNull);
    });

    test('constructs with all optional fields', () {
      final now = DateTime(2026, 5, 6, 10, 0);
      const failure = UnknownFailure(
        message: 'Network error',
        causeType: 'timeout',
      );
      final msg = PendingMessage(
        localId: 'local-2',
        content: 'With attachment',
        attachmentIds: const ['att-1', 'att-2'],
        createdAt: now,
        status: MessageSendStatus.failed,
        failure: failure,
      );

      expect(msg.attachmentIds, ['att-1', 'att-2']);
      expect(msg.status, MessageSendStatus.failed);
      expect(msg.failure, failure);
    });

    test('copyWith updates status and failure', () {
      final now = DateTime(2026, 5, 6, 10, 0);
      final msg = PendingMessage(
        localId: 'local-3',
        content: 'Test',
        createdAt: now,
      );

      final failed = msg.copyWith(
        status: MessageSendStatus.failed,
        failure: const UnknownFailure(
          message: 'Server error',
          causeType: 'http',
        ),
      );

      expect(failed.status, MessageSendStatus.failed);
      expect(failed.failure, isNotNull);
      expect(failed.localId, 'local-3');
      expect(failed.content, 'Test');
    });

    test('copyWith clearFailure removes failure', () {
      final now = DateTime(2026, 5, 6, 10, 0);
      final msg = PendingMessage(
        localId: 'local-4',
        content: 'Retry',
        createdAt: now,
        status: MessageSendStatus.failed,
        failure: const UnknownFailure(
          message: 'Error',
          causeType: 'x',
        ),
      );

      final retrying = msg.copyWith(
        status: MessageSendStatus.sending,
        clearFailure: true,
      );

      expect(retrying.status, MessageSendStatus.sending);
      expect(retrying.failure, isNull);
    });

    test('equality based on localId, content, status, createdAt', () {
      final now = DateTime(2026, 5, 6, 10, 0);
      final a = PendingMessage(
        localId: 'id-1',
        content: 'Hi',
        createdAt: now,
      );
      final b = PendingMessage(
        localId: 'id-1',
        content: 'Hi',
        createdAt: now,
      );
      final c = PendingMessage(
        localId: 'id-1',
        content: 'Hi',
        createdAt: now,
        status: MessageSendStatus.failed,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('MessageSendStatus enum', () {
    test('has three values', () {
      expect(MessageSendStatus.values.length, 3);
      expect(
        MessageSendStatus.values,
        containsAll([
          MessageSendStatus.sending,
          MessageSendStatus.sent,
          MessageSendStatus.failed,
        ]),
      );
    });
  });

  group('ConversationDetailStore send with optimistic insert', () {
    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'channel-1',
      ),
    );

    late _ControllableConversationRepository repo;

    ProviderContainer createContainer() {
      repo = _ControllableConversationRepository();
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      return container;
    }

    test('send inserts PendingMessage optimistically', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      // Load conversation first
      await container.read(conversationDetailStoreProvider.notifier).load();

      final store = container.read(conversationDetailStoreProvider.notifier);

      store.updateDraft('Hello world');

      // Setup controllable send
      repo.sendCompleter = Completer<ConversationMessageSummary>();
      final sendFuture = store.send();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.pendingMessages, hasLength(1));
      expect(state.pendingMessages.first.content, 'Hello world');
      expect(
        state.pendingMessages.first.status,
        MessageSendStatus.sending,
      );

      // Complete the send
      repo.sendCompleter!.complete(_fakeMessage('msg-1', 'Hello world'));
      await sendFuture;

      final afterState = container.read(conversationDetailStoreProvider);
      expect(afterState.pendingMessages, isEmpty);
      expect(afterState.messages.last.id, 'msg-1');
    });

    test('send transitions to failed on error', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      store.updateDraft('Fail me');
      repo.sendCompleter = Completer<ConversationMessageSummary>();
      final sendFuture = store.send();
      await Future<void>.delayed(Duration.zero);

      // Fail the send
      repo.sendCompleter!.completeError(
        const UnknownFailure(message: 'Network', causeType: 'timeout'),
      );
      await sendFuture;

      final state = container.read(conversationDetailStoreProvider);
      expect(state.pendingMessages, hasLength(1));
      expect(
        state.pendingMessages.first.status,
        MessageSendStatus.failed,
      );
      expect(state.pendingMessages.first.failure, isNotNull);
    });

    test('retrySend transitions failed → sending → sent', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      // Send and fail
      store.updateDraft('Retry me');
      repo.sendCompleter = Completer<ConversationMessageSummary>();
      final sendFuture = store.send();
      await Future<void>.delayed(Duration.zero);
      repo.sendCompleter!.completeError(
        const UnknownFailure(message: 'fail', causeType: 'x'),
      );
      await sendFuture;

      final localId = container
          .read(conversationDetailStoreProvider)
          .pendingMessages
          .first
          .localId;

      // Retry
      repo.sendCompleter = Completer<ConversationMessageSummary>();
      final retryFuture = store.retrySend(localId);
      await Future<void>.delayed(Duration.zero);

      final retryingState = container.read(conversationDetailStoreProvider);
      expect(
        retryingState.pendingMessages.first.status,
        MessageSendStatus.sending,
      );

      // Complete retry
      repo.sendCompleter!.complete(_fakeMessage('msg-retry', 'Retry me'));
      await retryFuture;

      final doneState = container.read(conversationDetailStoreProvider);
      expect(doneState.pendingMessages, isEmpty);
      expect(doneState.messages.last.id, 'msg-retry');
    });

    test('pending messages appear separate from confirmed messages', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      store.updateDraft('New message');
      repo.sendCompleter = Completer<ConversationMessageSummary>();
      store.send();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      // pendingMessages is separate from messages
      expect(state.messages, isEmpty);
      expect(state.pendingMessages, hasLength(1));

      // Clean up
      repo.sendCompleter!.complete(_fakeMessage('msg-x', 'New message'));
    });

    test('draft is cleared on optimistic insert', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      store.updateDraft('Clear me');
      repo.sendCompleter = Completer<ConversationMessageSummary>();
      store.send();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.draft, '');

      // Clean up
      repo.sendCompleter!.complete(_fakeMessage('msg-y', 'Clear me'));
    });

    test('dismissPendingMessage removes failed message', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      store.updateDraft('Dismiss me');
      repo.sendCompleter = Completer<ConversationMessageSummary>();
      final sendFuture = store.send();
      await Future<void>.delayed(Duration.zero);
      repo.sendCompleter!.completeError(
        const UnknownFailure(message: 'fail', causeType: 'x'),
      );
      await sendFuture;

      final localId = container
          .read(conversationDetailStoreProvider)
          .pendingMessages
          .first
          .localId;

      store.dismissPendingMessage(localId);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.pendingMessages, isEmpty);
    });

    test('multiple pending messages maintain insertion order', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      // Send first (don't complete)
      store.updateDraft('First');
      repo.sendCompleter = Completer<ConversationMessageSummary>();
      store.send();
      await Future<void>.delayed(Duration.zero);

      // Send second
      store.updateDraft('Second');
      final secondCompleter = Completer<ConversationMessageSummary>();
      repo.sendCompleter = secondCompleter;
      store.send();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.pendingMessages, hasLength(2));
      expect(state.pendingMessages[0].content, 'First');
      expect(state.pendingMessages[1].content, 'Second');
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

ConversationMessageSummary _fakeMessage(String id, String content) {
  return ConversationMessageSummary(
    id: id,
    content: content,
    createdAt: DateTime(2026, 5, 6, 10, 0),
    senderType: 'human',
    messageType: 'message',
  );
}

class _ControllableConversationRepository implements ConversationRepository {
  Completer<ConversationMessageSummary>? sendCompleter;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return ConversationDetailSnapshot(
      target: target,
      title: '#channel-1',
      messages: const [],
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
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
  }) {
    if (sendCompleter != null) {
      return sendCompleter!.future;
    }
    return Future.value(_fakeMessage('auto-id', content));
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment,
  ) async {
    return 'att-fake-id';
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
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}
