import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

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
          content: 'Hello',
          createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
          senderType: 'human',
          senderId: 'user-1',
          messageType: 'message',
          seq: 1,
        ),
        ConversationMessageSummary(
          id: 'message-2',
          content: 'World',
          createdAt: DateTime.parse('2026-04-19T15:01:00Z'),
          senderType: 'human',
          senderId: 'user-2',
          messageType: 'message',
          seq: 2,
          reactions: const [
            MessageReaction(emoji: '👍', count: 1, userIds: ['user-2']),
          ],
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    );
  }

  group('addReaction', () {
    test('optimistically adds reaction and calls API', () async {
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container
          .read(conversationDetailStoreProvider.notifier)
          .addReaction('message-1', '👍');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.reactions.length, 1);
      expect(state.messages.first.reactions.first.emoji, '👍');
      expect(state.messages.first.reactions.first.count, 1);
      expect(state.messages.first.reactions.first.userIds, ['user-1']);
      expect(repository.addedReactions, [('message-1', '👍')]);
    });

    test('increments existing reaction count', () async {
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      // message-2 already has 👍 from user-2
      await container
          .read(conversationDetailStoreProvider.notifier)
          .addReaction('message-2', '👍');

      final state = container.read(conversationDetailStoreProvider);
      final reaction = state.messages[1].reactions.first;
      expect(reaction.emoji, '👍');
      expect(reaction.count, 2);
      expect(reaction.userIds, ['user-2', 'user-1']);
    });

    test('reverts on API failure and rethrows', () async {
      const failure = ServerFailure(
        message: 'Forbidden.',
        statusCode: 403,
      );
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
        addReactionFailure: failure,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      await expectLater(
        container
            .read(conversationDetailStoreProvider.notifier)
            .addReaction('message-1', '👍'),
        throwsA(isA<ServerFailure>()),
      );

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.reactions, isEmpty);
    });

    test('does nothing when state is not success', () async {
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ],
      );
      addTearDown(container.dispose);

      // Don't call load()
      await container
          .read(conversationDetailStoreProvider.notifier)
          .addReaction('message-1', '👍');

      expect(repository.addedReactions, isEmpty);
    });
  });

  group('removeReaction', () {
    test('optimistically removes reaction and calls API', () async {
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-2')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      // message-2 has 👍 from user-2
      await container
          .read(conversationDetailStoreProvider.notifier)
          .removeReaction('message-2', '👍');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[1].reactions, isEmpty);
      expect(repository.removedReactions, [('message-2', '👍')]);
    });

    test('decrements count when multiple users reacted', () async {
      final snapshot = ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Hello',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            senderId: 'user-1',
            messageType: 'message',
            seq: 1,
            reactions: const [
              MessageReaction(
                emoji: '👍',
                count: 3,
                userIds: ['user-1', 'user-2', 'user-3'],
              ),
            ],
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      );
      final repository = _FakeConversationRepository(snapshot: snapshot);
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-2')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container
          .read(conversationDetailStoreProvider.notifier)
          .removeReaction('message-1', '👍');

      final state = container.read(conversationDetailStoreProvider);
      final reaction = state.messages.first.reactions.first;
      expect(reaction.count, 2);
      expect(reaction.userIds, ['user-1', 'user-3']);
    });

    test('reverts on API failure and rethrows', () async {
      const failure = ServerFailure(
        message: 'Forbidden.',
        statusCode: 403,
      );
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
        removeReactionFailure: failure,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-2')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      await expectLater(
        container
            .read(conversationDetailStoreProvider.notifier)
            .removeReaction('message-2', '👍'),
        throwsA(isA<ServerFailure>()),
      );

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[1].reactions.first.count, 1);
      expect(state.messages[1].reactions.first.userIds, ['user-2']);
    });
  });

  group('toggleReaction', () {
    test('adds reaction when user has not reacted', () async {
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container
          .read(conversationDetailStoreProvider.notifier)
          .toggleReaction('message-1', '❤️');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.reactions.length, 1);
      expect(state.messages.first.reactions.first.emoji, '❤️');
      expect(repository.addedReactions, [('message-1', '❤️')]);
      expect(repository.removedReactions, isEmpty);
    });

    test('removes reaction when user already reacted', () async {
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-2')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      // message-2 already has 👍 from user-2
      await container
          .read(conversationDetailStoreProvider.notifier)
          .toggleReaction('message-2', '👍');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[1].reactions, isEmpty);
      expect(repository.removedReactions, [('message-2', '👍')]);
      expect(repository.addedReactions, isEmpty);
    });

    test('deduplicates concurrent toggles for same message and emoji (#715)',
        () async {
      final removeCompleter = Completer<void>();
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
        removeReactionCompleter: removeCompleter,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-2')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);
      final first = store.toggleReaction('message-2', '👍');
      await Future<void>.delayed(Duration.zero);
      final second = store.toggleReaction('message-2', '👍');
      await Future<void>.delayed(Duration.zero);

      expect(repository.removedReactions, [('message-2', '👍')]);
      expect(repository.addedReactions, isEmpty);

      removeCompleter.complete();
      await Future.wait([first, second]);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[1].reactions, isEmpty);
    });
  });

  group('message:reaction_added realtime event', () {
    test('adds reaction from realtime event', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
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
        eventType: 'message:reaction_added',
        scopeKey: 'general',
        seq: 10,
        receivedAt: DateTime.now(),
        payload: const {
          'messageId': 'message-1',
          'channelId': 'general',
          'emoji': '🎉',
          'userId': 'user-3',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.reactions.length, 1);
      expect(state.messages.first.reactions.first.emoji, '🎉');
      expect(state.messages.first.reactions.first.count, 1);
      expect(state.messages.first.reactions.first.userIds, ['user-3']);
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
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
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
        eventType: 'message:reaction_added',
        scopeKey: 'other-channel',
        seq: 10,
        receivedAt: DateTime.now(),
        payload: const {
          'messageId': 'message-1',
          'channelId': 'other-channel',
          'emoji': '🎉',
          'userId': 'user-3',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.reactions, isEmpty);
    });
  });

  group('message:reaction_removed realtime event', () {
    test('removes reaction from realtime event', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
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

      // message-2 has 👍 from user-2
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:reaction_removed',
        scopeKey: 'general',
        seq: 11,
        receivedAt: DateTime.now(),
        payload: const {
          'messageId': 'message-2',
          'channelId': 'general',
          'emoji': '👍',
          'userId': 'user-2',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[1].reactions, isEmpty);
    });
  });

  group('reaction cache persistence', () {
    test('reactions survive cache restore after leaving and reopening',
        () async {
      final repository = _FakeConversationRepository(
        snapshot: twoMessageSnapshot(),
        newerPages: {
          2: const ConversationMessagePage(
            messages: [],
            historyLimited: false,
            hasOlder: false,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationDetailSessionStoreProvider
              .overrideWith(() => ConversationDetailSessionStore()),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ],
      );
      addTearDown(container.dispose);

      // First subscription — load and add reaction
      final sub1 = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await container.read(conversationDetailStoreProvider.notifier).load();
      await container
          .read(conversationDetailStoreProvider.notifier)
          .addReaction('message-1', '🔥');

      // Verify reaction applied
      final stateBeforeClose = container.read(conversationDetailStoreProvider);
      expect(stateBeforeClose.messages.first.reactions.length, 1);
      expect(stateBeforeClose.messages.first.reactions.first.emoji, '🔥');

      // Close subscription (simulate leaving conversation)
      sub1.close();
      await Future<void>.delayed(Duration.zero);

      // Reopen — create new subscription
      container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );

      // Restored state should have the reaction from cache
      final restoredState = container.read(conversationDetailStoreProvider);
      expect(restoredState.status, ConversationDetailStatus.success);
      expect(restoredState.messages.first.reactions.length, 1);
      expect(restoredState.messages.first.reactions.first.emoji, '🔥');
      expect(restoredState.messages.first.reactions.first.count, 1);
      expect(restoredState.messages.first.reactions.first.userIds, ['user-1']);
    });
  });
}

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore({this.userId});

  final String? userId;

  @override
  SessionState build() => SessionState(
        status: AuthStatus.authenticated,
        userId: userId,
      );
}

class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _FakeConversationRepository({
    required this.snapshot,
    this.addReactionFailure,
    this.removeReactionFailure,
    this.removeReactionCompleter,
    this.newerPages = const {},
  });

  final ConversationDetailSnapshot snapshot;
  final AppFailure? addReactionFailure;
  final AppFailure? removeReactionFailure;
  final Completer<void>? removeReactionCompleter;
  final Map<int, ConversationMessagePage> newerPages;
  final List<(String, String)> addedReactions = [];
  final List<(String, String)> removedReactions = [];

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
    return newerPages[afterSeq] ??
        const ConversationMessagePage(
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
  }) async {
    addedReactions.add((messageId, emoji));
    if (addReactionFailure != null) {
      throw addReactionFailure!;
    }
  }

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {
    removedReactions.add((messageId, emoji));
    if (removeReactionCompleter != null) {
      await removeReactionCompleter!.future;
    }
    if (removeReactionFailure != null) {
      throw removeReactionFailure!;
    }
  }

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
