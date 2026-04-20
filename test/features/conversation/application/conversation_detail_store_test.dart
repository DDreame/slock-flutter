import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  test('load populates title and messages on success', () async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Hello world',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
          ),
        ],
        historyLimited: true,
        hasOlder: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationDetailStoreProvider.notifier).load();
    final state = container.read(conversationDetailStoreProvider);

    expect(state.status, ConversationDetailStatus.success);
    expect(state.title, '#general');
    expect(state.messages.single.content, 'Hello world');
    expect(state.historyLimited, isTrue);
    expect(state.hasOlder, isTrue);
    expect(repository.requestedTargets, [target]);
  });

  test('load stores typed AppFailure in state without rethrowing', () async {
    const failure = ServerFailure(
      message: 'Conversation load failed.',
      statusCode: 500,
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(
          _FakeConversationRepository(failure: failure),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationDetailStoreProvider.notifier).load();
    final state = container.read(conversationDetailStoreProvider);

    expect(state.status, ConversationDetailStatus.failure);
    expect(state.failure, failure);
    expect(state.messages, isEmpty);
    expect(state.resolvedTitle, '#general');
  });

  test('send appends deduped message and clears draft on success', () async {
    final sentMessage = ConversationMessageSummary(
      id: 'message-2',
      content: 'New message',
      createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: 2,
    );
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Hello world',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
          ),
        ],
        historyLimited: true,
        hasOlder: false,
      ),
      sentMessage: sentMessage,
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationDetailStoreProvider.notifier).load();
    final notifier = container.read(conversationDetailStoreProvider.notifier);

    notifier.updateDraft('  New message  ');
    await notifier.send();

    final state = container.read(conversationDetailStoreProvider);
    expect(state.isSending, isFalse);
    expect(state.draft, isEmpty);
    expect(state.sendFailure, isNull);
    expect(state.messages.map((message) => message.id),
        ['message-1', 'message-2']);
    expect(repository.sentContents, ['New message']);
  });

  test('send preserves draft and stores typed AppFailure on failure', () async {
    const failure = ServerFailure(
      message: 'Send failed.',
      statusCode: 500,
    );
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
      sendFailure: failure,
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationDetailStoreProvider.notifier).load();
    final notifier = container.read(conversationDetailStoreProvider.notifier);

    notifier.updateDraft('Retry me');
    await notifier.send();

    final state = container.read(conversationDetailStoreProvider);
    expect(state.isSending, isFalse);
    expect(state.draft, 'Retry me');
    expect(state.sendFailure, failure);
    expect(state.messages, isEmpty);
  });

  test('realtime append shares send dedupe truth by message id', () async {
    final sentMessage = ConversationMessageSummary(
      id: 'message-2',
      content: 'Realtime echo',
      createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: 2,
    );
    final ingress = RealtimeReductionIngress();
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
      sentMessage: sentMessage,
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
    final notifier = container.read(conversationDetailStoreProvider.notifier);

    notifier.updateDraft('Realtime echo');
    await notifier.send();

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime(2026, 4, 20),
        seq: 2,
        payload: {
          'id': 'message-2',
          'channelId': target.conversationId,
          'content': 'Realtime echo',
          'createdAt': '2026-04-19T15:05:00Z',
          'senderType': 'human',
          'messageType': 'message',
          'senderId': 'other-user',
          'seq': 2,
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(conversationDetailStoreProvider);
    expect(state.messages.map((message) => message.id), ['message-2']);
  });

  test('loadOlder prepends deduped older messages and updates hasOlder',
      () async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-3',
            content: 'Newest loaded',
            createdAt: DateTime.parse('2026-04-19T15:02:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 3,
          ),
        ],
        historyLimited: false,
        hasOlder: true,
      ),
      olderPages: {
        3: ConversationMessagePage(
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Older 1',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
            ConversationMessageSummary(
              id: 'message-2',
              content: 'Older 2',
              createdAt: DateTime.parse('2026-04-19T15:01:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 2,
            ),
            ConversationMessageSummary(
              id: 'message-3',
              content: 'Newest loaded',
              createdAt: DateTime.parse('2026-04-19T15:02:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 3,
            ),
          ],
          historyLimited: true,
          hasOlder: false,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationDetailStoreProvider.notifier).load();
    await container.read(conversationDetailStoreProvider.notifier).loadOlder();

    final state = container.read(conversationDetailStoreProvider);
    expect(state.messages.map((message) => message.id), [
      'message-1',
      'message-2',
      'message-3',
    ]);
    expect(state.hasOlder, isFalse);
    expect(state.historyLimited, isTrue);
    expect(repository.olderRequests, [3]);
  });

  test('ensureLoaded restores cached window without re-requesting', () async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Cached',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      conversationDetailStoreProvider,
      (_, __) {},
      fireImmediately: true,
    );
    await container.read(conversationDetailStoreProvider.notifier).load();
    subscription.close();
    await Future<void>.delayed(Duration.zero);

    final restoredState = container.read(conversationDetailStoreProvider);
    expect(restoredState.status, ConversationDetailStatus.success);
    expect(restoredState.messages.single.content, 'Cached');

    await container
        .read(conversationDetailStoreProvider.notifier)
        .ensureLoaded();

    expect(repository.requestedTargets, [target]);
  });
  test('realtime-first then send response deduplicates by message id',
      () async {
    final ingress = RealtimeReductionIngress();
    final sentMessage = ConversationMessageSummary(
      id: 'message-2',
      content: 'Race message',
      createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: 2,
    );
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
      sentMessage: sentMessage,
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
    final notifier = container.read(conversationDetailStoreProvider.notifier);

    notifier.updateDraft('Race message');

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime(2026, 4, 20),
        seq: 2,
        payload: {
          'id': 'message-2',
          'channelId': target.conversationId,
          'content': 'Race message',
          'createdAt': '2026-04-19T15:05:00Z',
          'senderType': 'human',
          'messageType': 'message',
          'senderId': 'other-user',
          'seq': 2,
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.send();

    final state = container.read(conversationDetailStoreProvider);
    expect(state.messages.map((message) => message.id), ['message-2']);
  });
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({
    this.snapshot,
    this.failure,
    this.olderPages = const {},
    this.sentMessage,
    this.sendFailure,
  });

  final ConversationDetailSnapshot? snapshot;
  final AppFailure? failure;
  final Map<int, ConversationMessagePage> olderPages;
  final ConversationMessageSummary? sentMessage;
  final AppFailure? sendFailure;
  final List<ConversationDetailTarget> requestedTargets = [];
  final List<int> olderRequests = [];
  final List<String> sentContents = [];

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    requestedTargets.add(target);
    if (failure != null) {
      throw failure!;
    }
    return snapshot!;
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    olderRequests.add(beforeSeq);
    return olderPages[beforeSeq]!;
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content,
  ) async {
    sentContents.add(content);
    if (sendFailure != null) {
      throw sendFailure!;
    }
    return sentMessage!;
  }
}
