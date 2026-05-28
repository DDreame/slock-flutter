import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
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

  ConversationDetailSnapshot twoMessageSnapshot() {
    return ConversationDetailSnapshot(
      target: target,
      title: '#general',
      messages: [
        ConversationMessageSummary(
          id: 'message-1',
          content: 'Original content',
          createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
          senderType: 'human',
          senderId: 'user-1',
          messageType: 'message',
          seq: 1,
        ),
        ConversationMessageSummary(
          id: 'message-2',
          content: 'Second message',
          createdAt: DateTime.parse('2026-04-19T15:01:00Z'),
          senderType: 'human',
          senderId: 'user-2',
          messageType: 'message',
          seq: 2,
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    );
  }

  group('editMessage', () {
    test('optimistically updates message content and calls API', () async {
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container
          .read(conversationDetailStoreProvider.notifier)
          .editMessage('message-1', 'Updated content');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.content, 'Updated content');
      expect(repository.editedMessages, {'message-1': 'Updated content'});
    });

    test('reverts content on API failure and rethrows', () async {
      const failure = ServerFailure(
        message: 'Forbidden.',
        statusCode: 403,
      );
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
        editFailure: failure,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      await expectLater(
        container
            .read(conversationDetailStoreProvider.notifier)
            .editMessage('message-1', 'Will revert'),
        throwsA(isA<ServerFailure>()),
      );

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.content, 'Original content');
    });

    test('failure rollback persists restored content to session cache (#718)',
        () async {
      const failure = ServerFailure(
        message: 'Forbidden.',
        statusCode: 403,
      );
      final editCompleter = Completer<void>();
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
        editFailure: failure,
        editCompleter: editCompleter,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationDetailSessionStoreProvider
              .overrideWith(() => ConversationDetailSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final editFuture = container
          .read(conversationDetailStoreProvider.notifier)
          .editMessage('message-1', 'Will revert');
      await Future<void>.value();

      container
          .read(conversationDetailSessionStoreProvider.notifier)
          .saveSuccessState(
            container.read(conversationDetailStoreProvider),
            scrollOffset: 12,
          );

      editCompleter.complete();
      await expectLater(editFuture, throwsA(isA<ServerFailure>()));

      final cached =
          container.read(conversationDetailSessionStoreProvider)[target]!;
      expect(cached.messages.first.content, 'Original content');
      expect(cached.scrollOffset, 12);
    });

    test('does nothing when state is not success', () async {
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      // Don't call load(), so state is still initial
      await container
          .read(conversationDetailStoreProvider.notifier)
          .editMessage('message-1', 'Ignored');

      expect(repository.editedMessages, isEmpty);
    });

    test('does nothing when message id not found', () async {
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container
          .read(conversationDetailStoreProvider.notifier)
          .editMessage('nonexistent', 'Ignored');

      expect(repository.editedMessages, isEmpty);
    });
  });

  group('message:updated realtime event', () {
    test('updates message content from realtime event', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Emit a message:updated event
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:updated',
        scopeKey: 'general',
        seq: 10,
        receivedAt: DateTime.now(),
        payload: const {
          'id': 'message-1',
          'channelId': 'general',
          'content': 'Remotely edited',
        },
      ));

      // Wait for the async handler to process
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.content, 'Remotely edited');
    });

    test('ignores event for different channel', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:updated',
        scopeKey: 'other-channel',
        seq: 10,
        receivedAt: DateTime.now(),
        payload: const {
          'id': 'message-1',
          'channelId': 'other-channel',
          'content': 'Should not apply',
        },
      ));

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.content, 'Original content');
    });
  });

  group('deleteMessage', () {
    test('marks message as deleted and calls repo', () async {
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container
          .read(conversationDetailStoreProvider.notifier)
          .deleteMessage('message-1');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.length, 2);
      expect(state.messages.first.isDeleted, isTrue);
      expect(state.messages.last.isDeleted, isFalse);
      expect(repository.deletedMessageIds, ['message-1']);
    });

    test('reverts on failure and rethrows', () async {
      const failure = ServerFailure(
        message: 'Forbidden.',
        statusCode: 403,
      );
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
        deleteFailure: failure,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      await expectLater(
        container
            .read(conversationDetailStoreProvider.notifier)
            .deleteMessage('message-1'),
        throwsA(isA<ServerFailure>()),
      );

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.isDeleted, isFalse);
      expect(state.messages.map((m) => m.id), ['message-1', 'message-2']);
    });

    test(
        'failure rollback persists restored deleted flag to session cache (#718)',
        () async {
      const failure = ServerFailure(
        message: 'Forbidden.',
        statusCode: 403,
      );
      final deleteCompleter = Completer<void>();
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
        deleteFailure: failure,
        deleteCompleter: deleteCompleter,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationDetailSessionStoreProvider
              .overrideWith(() => ConversationDetailSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final deleteFuture = container
          .read(conversationDetailStoreProvider.notifier)
          .deleteMessage('message-1');
      await Future<void>.value();

      container
          .read(conversationDetailSessionStoreProvider.notifier)
          .saveSuccessState(
            container.read(conversationDetailStoreProvider),
            scrollOffset: 24,
          );

      deleteCompleter.complete();
      await expectLater(deleteFuture, throwsA(isA<ServerFailure>()));

      final cached =
          container.read(conversationDetailSessionStoreProvider)[target]!;
      expect(cached.messages.first.isDeleted, isFalse);
      expect(cached.scrollOffset, 24);
    });

    test('message:deleted realtime event marks message as deleted', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:deleted',
        scopeKey: 'general',
        seq: 10,
        receivedAt: DateTime.now(),
        payload: const {
          'id': 'message-1',
          'channelId': 'general',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.length, 2);
      expect(state.messages.first.isDeleted, isTrue);
      expect(state.messages.last.isDeleted, isFalse);
    });
  });
}

class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _FakeConversationRepository({
    required this.snapshot,
    this.editFailure,
    this.deleteFailure,
    this.editCompleter,
    this.deleteCompleter,
  });

  final ConversationDetailSnapshot snapshot;
  final AppFailure? editFailure;
  final AppFailure? deleteFailure;
  final Completer<void>? editCompleter;
  final Completer<void>? deleteCompleter;
  final Map<String, String> editedMessages = {};
  final List<String> deletedMessageIds = [];

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
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
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
    // Simulate the local store update
    for (final msg in snapshot.messages) {
      if (msg.id == messageId) {
        return msg.copyWith(content: content);
      }
    }
    return null;
  }

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    editedMessages[messageId] = content;
    if (editCompleter != null) {
      await editCompleter!.future;
    }
    if (editFailure != null) {
      throw editFailure!;
    }
  }

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    deletedMessageIds.add(messageId);
    if (deleteCompleter != null) {
      await deleteCompleter!.future;
    }
    if (deleteFailure != null) {
      throw deleteFailure!;
    }
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
