import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/pinned_messages_store.dart';
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

  ConversationDetailSnapshot baseSnapshot() {
    return ConversationDetailSnapshot(
      target: target,
      title: '#general',
      messages: [
        ConversationMessageSummary(
          id: 'message-1',
          content: 'Hello',
          createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
          senderType: 'human',
          senderId: 'user-1',
          messageType: 'message',
          seq: 1,
        ),
        ConversationMessageSummary(
          id: 'message-2',
          content: 'Pinned already',
          createdAt: DateTime.parse('2026-05-07T10:01:00Z'),
          senderType: 'human',
          senderId: 'user-2',
          messageType: 'message',
          seq: 2,
          isPinned: true,
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    );
  }

  group('PinnedMessagesState equality', () {
    test('hashCode includes message contents for same-length lists (#718)', () {
      final first = ConversationMessageSummary(
        id: 'message-1',
        content: 'First',
        createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      );
      final second = ConversationMessageSummary(
        id: 'message-2',
        content: 'Second',
        createdAt: DateTime.parse('2026-05-07T10:01:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 2,
      );

      final a = PinnedMessagesState(
        status: PinnedMessagesStatus.success,
        messages: [first],
      );
      final b = PinnedMessagesState(
        status: PinnedMessagesStatus.success,
        messages: [second],
      );

      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
    });
  });

  group('pinMessage', () {
    test('optimistically pins and calls API', () async {
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
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
          .pinMessage('message-1');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.isPinned, isTrue);
      expect(repository.pinnedMessageIds, ['message-1']);
    });

    test('reverts on API failure and rethrows', () async {
      const failure = ServerFailure(
        message: 'Forbidden.',
        statusCode: 403,
      );
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
        pinFailure: failure,
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
            .pinMessage('message-1'),
        throwsA(isA<ServerFailure>()),
      );

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.isPinned, isFalse);
    });

    test('does nothing when state is not success', () async {
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
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
          .pinMessage('message-1');

      expect(repository.pinnedMessageIds, isEmpty);
    });
  });

  group('unpinMessage', () {
    test('optimistically unpins and calls API', () async {
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
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
      // message-2 is already pinned
      await container
          .read(conversationDetailStoreProvider.notifier)
          .unpinMessage('message-2');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[1].isPinned, isFalse);
      expect(repository.unpinnedMessageIds, ['message-2']);
    });

    test('reverts on API failure and rethrows', () async {
      const failure = ServerFailure(
        message: 'Forbidden.',
        statusCode: 403,
      );
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
        unpinFailure: failure,
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
            .unpinMessage('message-2'),
        throwsA(isA<ServerFailure>()),
      );

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[1].isPinned, isTrue);
    });
  });

  group('message:pinned realtime event', () {
    test('pins message from realtime event', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
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
        eventType: 'message:pinned',
        scopeKey: 'general',
        seq: 10,
        receivedAt: DateTime.now(),
        payload: const {
          'messageId': 'message-1',
          'channelId': 'general',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.isPinned, isTrue);
    });

    test('ignores event for different channel', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
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
        eventType: 'message:pinned',
        scopeKey: 'other-channel',
        seq: 10,
        receivedAt: DateTime.now(),
        payload: const {
          'messageId': 'message-1',
          'channelId': 'other-channel',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.isPinned, isFalse);
    });
  });

  group('message:unpinned realtime event', () {
    test('unpins message from realtime event', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
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

      // message-2 is pinned
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:unpinned',
        scopeKey: 'general',
        seq: 11,
        receivedAt: DateTime.now(),
        payload: const {
          'messageId': 'message-2',
          'channelId': 'general',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[1].isPinned, isFalse);
    });
  });

  group('PinnedMessagesStore', () {
    test('loads pinned messages from API', () async {
      final pinnedMessages = [
        ConversationMessageSummary(
          id: 'message-2',
          content: 'Pinned already',
          createdAt: DateTime.parse('2026-05-07T10:01:00Z'),
          senderType: 'human',
          senderId: 'user-2',
          messageType: 'message',
          seq: 2,
          isPinned: true,
        ),
      ];
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
        pinnedMessages: pinnedMessages,
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

      await container.read(pinnedMessagesStoreProvider.notifier).load();

      final state = container.read(pinnedMessagesStoreProvider);
      expect(state.status, PinnedMessagesStatus.success);
      expect(state.messages.length, 1);
      expect(state.messages.first.id, 'message-2');
    });

    test('handles API failure gracefully', () async {
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
        loadPinnedFailure: const ServerFailure(
          message: 'Not found.',
          statusCode: 404,
        ),
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

      await container.read(pinnedMessagesStoreProvider.notifier).load();

      final state = container.read(pinnedMessagesStoreProvider);
      expect(state.status, PinnedMessagesStatus.failure);
      expect(state.failure, isA<AppFailure>());
    });

    test('removeMessage removes from list', () async {
      final pinnedMessages = [
        ConversationMessageSummary(
          id: 'message-2',
          content: 'Pinned',
          createdAt: DateTime.parse('2026-05-07T10:01:00Z'),
          senderType: 'human',
          senderId: 'user-2',
          messageType: 'message',
          seq: 2,
          isPinned: true,
        ),
      ];
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
        pinnedMessages: pinnedMessages,
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

      await container.read(pinnedMessagesStoreProvider.notifier).load();
      container
          .read(pinnedMessagesStoreProvider.notifier)
          .removeMessage('message-2');

      final state = container.read(pinnedMessagesStoreProvider);
      expect(state.messages, isEmpty);
    });

    test('addMessage is no-op for duplicate message IDs', () async {
      final pinnedMessages = [
        ConversationMessageSummary(
          id: 'message-2',
          content: 'Pinned',
          createdAt: DateTime.parse('2026-05-07T10:01:00Z'),
          senderType: 'human',
          senderId: 'user-2',
          messageType: 'message',
          seq: 2,
          isPinned: true,
        ),
      ];
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
        pinnedMessages: pinnedMessages,
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

      await container.read(pinnedMessagesStoreProvider.notifier).load();

      // Add duplicate — should be no-op.
      container.read(pinnedMessagesStoreProvider.notifier).addMessage(
            ConversationMessageSummary(
              id: 'message-2',
              content: 'Pinned duplicate',
              createdAt: DateTime.parse('2026-05-07T10:01:00Z'),
              senderType: 'human',
              senderId: 'user-2',
              messageType: 'message',
              seq: 2,
              isPinned: true,
            ),
          );

      final state = container.read(pinnedMessagesStoreProvider);
      expect(state.messages.length, 1);
    });

    test('addMessage is no-op when state is not success', () async {
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
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

      // Don't call load() — state remains initial.
      container.read(pinnedMessagesStoreProvider.notifier).addMessage(
            ConversationMessageSummary(
              id: 'message-1',
              content: 'New pin',
              createdAt: DateTime.parse('2026-05-07T10:00:00Z'),
              senderType: 'human',
              senderId: 'user-1',
              messageType: 'message',
              seq: 1,
            ),
          );

      final state = container.read(pinnedMessagesStoreProvider);
      expect(state.status, PinnedMessagesStatus.initial);
      expect(state.messages, isEmpty);
    });

    test('removeMessage is no-op when state is not success', () async {
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
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

      // Don't call load() — state remains initial.
      container
          .read(pinnedMessagesStoreProvider.notifier)
          .removeMessage('message-2');

      final state = container.read(pinnedMessagesStoreProvider);
      expect(state.status, PinnedMessagesStatus.initial);
      expect(state.messages, isEmpty);
    });
  });

  group('pinned list sync from conversation store', () {
    test('pinMessage adds to pinned list when store is alive', () async {
      final pinnedMessages = <ConversationMessageSummary>[];
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
        pinnedMessages: pinnedMessages,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ],
      );
      // Keep pinned store alive with a listener
      final pinnedSub = container.listen(
        pinnedMessagesStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() {
        pinnedSub.close();
        container.dispose();
      });

      // Load conversation
      await container.read(conversationDetailStoreProvider.notifier).load();
      // Load pinned list (makes store alive)
      await container.read(pinnedMessagesStoreProvider.notifier).load();

      // Pin message-1
      await container
          .read(conversationDetailStoreProvider.notifier)
          .pinMessage('message-1');

      final pinnedState = container.read(pinnedMessagesStoreProvider);
      expect(pinnedState.messages.any((m) => m.id == 'message-1'), isTrue);
    });

    test('unpinMessage removes from pinned list when store is alive', () async {
      final pinnedMessages = [
        ConversationMessageSummary(
          id: 'message-2',
          content: 'Pinned already',
          createdAt: DateTime.parse('2026-05-07T10:01:00Z'),
          senderType: 'human',
          senderId: 'user-2',
          messageType: 'message',
          seq: 2,
          isPinned: true,
        ),
      ];
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
        pinnedMessages: pinnedMessages,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ],
      );
      final pinnedSub = container.listen(
        pinnedMessagesStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() {
        pinnedSub.close();
        container.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container.read(pinnedMessagesStoreProvider.notifier).load();

      // Unpin message-2
      await container
          .read(conversationDetailStoreProvider.notifier)
          .unpinMessage('message-2');

      final pinnedState = container.read(pinnedMessagesStoreProvider);
      expect(pinnedState.messages.any((m) => m.id == 'message-2'), isFalse);
    });

    test('pinMessage reverts pinned list on API failure', () async {
      const failure = ServerFailure(
        message: 'Forbidden.',
        statusCode: 403,
      );
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
        pinFailure: failure,
        pinnedMessages: [],
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ],
      );
      final pinnedSub = container.listen(
        pinnedMessagesStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() {
        pinnedSub.close();
        container.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container.read(pinnedMessagesStoreProvider.notifier).load();

      await expectLater(
        container
            .read(conversationDetailStoreProvider.notifier)
            .pinMessage('message-1'),
        throwsA(isA<ServerFailure>()),
      );

      final pinnedState = container.read(pinnedMessagesStoreProvider);
      expect(pinnedState.messages.any((m) => m.id == 'message-1'), isFalse);
    });

    test('realtime pin event syncs to pinned list', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
        pinnedMessages: [],
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
      final detailSub = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      final pinnedSub = container.listen(
        pinnedMessagesStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        pinnedSub.close();
        detailSub.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container.read(pinnedMessagesStoreProvider.notifier).load();

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:pinned',
        scopeKey: 'general',
        seq: 10,
        receivedAt: DateTime.now(),
        payload: const {
          'messageId': 'message-1',
          'channelId': 'general',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final pinnedState = container.read(pinnedMessagesStoreProvider);
      expect(pinnedState.messages.any((m) => m.id == 'message-1'), isTrue);
    });

    test('realtime unpin event syncs to pinned list', () async {
      final ingress = RealtimeReductionIngress();
      final pinnedMessages = [
        ConversationMessageSummary(
          id: 'message-2',
          content: 'Pinned already',
          createdAt: DateTime.parse('2026-05-07T10:01:00Z'),
          senderType: 'human',
          senderId: 'user-2',
          messageType: 'message',
          seq: 2,
          isPinned: true,
        ),
      ];
      final repository = _FakeConversationRepository(
        snapshot: baseSnapshot(),
        pinnedMessages: pinnedMessages,
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
      final detailSub = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      final pinnedSub = container.listen(
        pinnedMessagesStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        pinnedSub.close();
        detailSub.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container.read(pinnedMessagesStoreProvider.notifier).load();

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:unpinned',
        scopeKey: 'general',
        seq: 11,
        receivedAt: DateTime.now(),
        payload: const {
          'messageId': 'message-2',
          'channelId': 'general',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      final pinnedState = container.read(pinnedMessagesStoreProvider);
      expect(pinnedState.messages.any((m) => m.id == 'message-2'), isFalse);
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
    this.pinFailure,
    this.unpinFailure,
    this.pinnedMessages = const [],
    this.loadPinnedFailure,
  });

  final ConversationDetailSnapshot snapshot;
  final AppFailure? pinFailure;
  final AppFailure? unpinFailure;
  final List<ConversationMessageSummary> pinnedMessages;
  final AppFailure? loadPinnedFailure;
  final List<String> pinnedMessageIds = [];
  final List<String> unpinnedMessageIds = [];

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
  }) async {
    pinnedMessageIds.add(messageId);
    if (pinFailure != null) {
      throw pinFailure!;
    }
  }

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    unpinnedMessageIds.add(messageId);
    if (unpinFailure != null) {
      throw unpinFailure!;
    }
  }

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async {
    if (loadPinnedFailure != null) {
      throw loadPinnedFailure!;
    }
    return pinnedMessages;
  }

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
