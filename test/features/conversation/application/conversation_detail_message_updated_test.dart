import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
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
      content: 'Original content',
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

  ProviderContainer createLoadedContainer({
    required RealtimeReductionIngress ingress,
    List<ConversationMessageSummary>? messages,
  }) {
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(
          _FakeConversationRepository(
            snapshot: ConversationDetailSnapshot(
              target: target,
              title: '#general',
              messages: messages ?? baseMessages,
              historyLimited: false,
              hasOlder: false,
            ),
          ),
        ),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
      ],
    );
    return container;
  }

  group('message:updated detail-side patch', () {
    test('patches content of existing message by id', () async {
      final ingress = RealtimeReductionIngress();
      final container = createLoadedContainer(ingress: ingress);
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

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:updated',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 3,
          payload: {
            'id': 'msg-1',
            'channelId': target.conversationId,
            'content': 'Edited content',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[0].content, 'Edited content');
      expect(state.messages[0].id, 'msg-1');
      expect(
          state.messages[0].createdAt, DateTime.parse('2026-04-19T15:00:00Z'));
      expect(state.messages[0].senderType, 'human');
      expect(state.messages[1].content, 'Second message');
    });

    test('ignores message:updated for unknown message id', () async {
      final ingress = RealtimeReductionIngress();
      final container = createLoadedContainer(ingress: ingress);
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

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:updated',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 3,
          payload: {
            'id': 'unknown-msg',
            'channelId': target.conversationId,
            'content': 'Edited content',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[0].content, 'Original content');
      expect(state.messages[1].content, 'Second message');
    });

    test('ignores message:updated for different conversation', () async {
      final ingress = RealtimeReductionIngress();
      final container = createLoadedContainer(ingress: ingress);
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

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:updated',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 3,
          payload: const {
            'id': 'msg-1',
            'channelId': 'other-channel',
            'content': 'Edited content',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[0].content, 'Original content');
    });

    test('ignores message:updated when not in success state', () async {
      final ingress = RealtimeReductionIngress();
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(
            _FakeConversationRepository(
              failure: const ServerFailure(
                message: 'fail',
                statusCode: 500,
              ),
            ),
          ),
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
      expect(
        container.read(conversationDetailStoreProvider).status,
        ConversationDetailStatus.failure,
      );

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:updated',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 3,
          payload: {
            'id': 'msg-1',
            'channelId': target.conversationId,
            'content': 'Edited content',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(conversationDetailStoreProvider).status,
        ConversationDetailStatus.failure,
      );
    });
  });
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({this.snapshot, this.failure});

  final ConversationDetailSnapshot? snapshot;
  final AppFailure? failure;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    if (failure != null) throw failure!;
    return snapshot!;
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment,
  ) async {
    throw UnimplementedError();
  }
}
