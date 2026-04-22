import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';

import '../../../core/local_data/fake_conversation_local_store.dart';

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
      content: 'Hello world',
      createdAt: DateTime.parse('2026-04-21T10:00:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: 1,
    ),
    ConversationMessageSummary(
      id: 'msg-2',
      content: 'Goodbye world',
      createdAt: DateTime.parse('2026-04-21T10:01:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: 2,
    ),
  ];

  late _FakeSavedMessagesRepository fakeSavedRepo;

  ProviderContainer createContainer() {
    final ingress = RealtimeReductionIngress();
    final fakeLocalStore = FakeConversationLocalStore();
    fakeSavedRepo = _FakeSavedMessagesRepository();
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(
          _FakeConversationRepository(
            snapshot: ConversationDetailSnapshot(
              target: target,
              title: '#general',
              messages: messages,
              historyLimited: false,
              hasOlder: false,
            ),
          ),
        ),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        conversationLocalStoreProvider.overrideWithValue(fakeLocalStore),
        savedMessagesRepositoryProvider.overrideWithValue(fakeSavedRepo),
      ],
    );
    return container;
  }

  group('saved message toggle', () {
    test('refreshSavedMessageIds populates savedMessageIds', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();
      await Future<void>.delayed(Duration.zero);

      fakeSavedRepo.checkResult = {'msg-1'};
      await container
          .read(conversationDetailStoreProvider.notifier)
          .refreshSavedMessageIds();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.savedMessageIds, {'msg-1'});
    });

    test('toggleSaveMessage optimistically adds then confirms', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();
      // Let unawaited refreshSavedMessageIds settle
      await Future<void>.delayed(Duration.zero);

      await container
          .read(conversationDetailStoreProvider.notifier)
          .toggleSaveMessage('msg-1');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.savedMessageIds.contains('msg-1'), isTrue);
      expect(fakeSavedRepo.savedIds, contains('msg-1'));
    });

    test('toggleSaveMessage optimistically removes then confirms', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();
      await Future<void>.delayed(Duration.zero);

      fakeSavedRepo.checkResult = {'msg-1'};
      await container
          .read(conversationDetailStoreProvider.notifier)
          .refreshSavedMessageIds();

      await container
          .read(conversationDetailStoreProvider.notifier)
          .toggleSaveMessage('msg-1');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.savedMessageIds.contains('msg-1'), isFalse);
      expect(fakeSavedRepo.unsavedIds, contains('msg-1'));
    });

    test('toggleSaveMessage reverts on failure', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();
      await Future<void>.delayed(Duration.zero);

      fakeSavedRepo.shouldFailToggle = true;

      await container
          .read(conversationDetailStoreProvider.notifier)
          .toggleSaveMessage('msg-1');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.savedMessageIds.contains('msg-1'), isFalse);
    });

    test('refreshSavedMessageIds silently fails on error', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();
      await Future<void>.delayed(Duration.zero);

      fakeSavedRepo.shouldFailCheck = true;
      await container
          .read(conversationDetailStoreProvider.notifier)
          .refreshSavedMessageIds();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.savedMessageIds, isEmpty);
    });
  });
}

class _FakeSavedMessagesRepository implements SavedMessagesRepository {
  Set<String> checkResult = {};
  bool shouldFailToggle = false;
  bool shouldFailCheck = false;
  final List<String> savedIds = [];
  final List<String> unsavedIds = [];

  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return const SavedMessagesPage(items: [], hasMore: false);
  }

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {
    if (shouldFailToggle) {
      throw const UnknownFailure(
        message: 'Save failed',
        causeType: 'test',
      );
    }
    savedIds.add(messageId);
  }

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {
    if (shouldFailToggle) {
      throw const UnknownFailure(
        message: 'Unsave failed',
        causeType: 'test',
      );
    }
    unsavedIds.add(messageId);
  }

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async {
    if (shouldFailCheck) {
      throw const UnknownFailure(
        message: 'Check failed',
        causeType: 'test',
      );
    }
    return checkResult;
  }
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({this.snapshot});

  final ConversationDetailSnapshot? snapshot;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
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
    return const ConversationMessagePage(
      messages: [],
      hasOlder: false,
      hasNewer: false,
      historyLimited: false,
    );
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

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    throw UnimplementedError();
  }
}
