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
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({
    this.snapshot,
    this.failure,
    this.sentMessage,
    this.sendFailure,
  });

  final ConversationDetailSnapshot? snapshot;
  final AppFailure? failure;
  final ConversationMessageSummary? sentMessage;
  final AppFailure? sendFailure;
  final List<ConversationDetailTarget> requestedTargets = [];
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
