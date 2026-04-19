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
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({this.snapshot, this.failure});

  final ConversationDetailSnapshot? snapshot;
  final AppFailure? failure;
  final List<ConversationDetailTarget> requestedTargets = [];

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
}
