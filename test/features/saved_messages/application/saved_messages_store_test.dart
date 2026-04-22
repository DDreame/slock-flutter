import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_state.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  late _FakeSavedMessagesRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = _FakeSavedMessagesRepository();
    container = ProviderContainer(overrides: [
      currentSavedMessagesServerIdProvider.overrideWithValue(serverId),
      savedMessagesRepositoryProvider.overrideWithValue(fakeRepo),
    ]);
  });

  tearDown(() => container.dispose());

  SavedMessagesStore store() =>
      container.read(savedMessagesStoreProvider.notifier);
  SavedMessagesState state() => container.read(savedMessagesStoreProvider);

  group('saved messages store', () {
    test('initial state is initial', () {
      expect(state().status, SavedMessagesStatus.initial);
      expect(state().items, isEmpty);
    });

    test('load fetches saved messages', () async {
      fakeRepo.listResult = SavedMessagesPage(
        items: [
          SavedMessageItem(
            message: ConversationMessageSummary(
              id: 'msg-1',
              content: 'Hello world',
              createdAt: DateTime(2026, 4, 21),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch1',
            channelName: 'general',
          ),
        ],
        hasMore: false,
      );

      await store().load();

      expect(state().status, SavedMessagesStatus.success);
      expect(state().items.length, 1);
      expect(state().items.first.message.id, 'msg-1');
      expect(state().hasMore, false);
    });

    test('load failure sets failure state', () async {
      fakeRepo.shouldFail = true;

      await store().load();

      expect(state().status, SavedMessagesStatus.failure);
      expect(state().failure, isNotNull);
    });

    test('loadMore appends pages', () async {
      fakeRepo.listResult = SavedMessagesPage(
        items: [
          SavedMessageItem(
            message: ConversationMessageSummary(
              id: 'msg-1',
              content: 'First',
              createdAt: DateTime(2026, 4, 21),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch1',
          ),
        ],
        hasMore: true,
      );

      await store().load();
      expect(state().items.length, 1);

      fakeRepo.listResult = SavedMessagesPage(
        items: [
          SavedMessageItem(
            message: ConversationMessageSummary(
              id: 'msg-2',
              content: 'Second',
              createdAt: DateTime(2026, 4, 22),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch1',
          ),
        ],
        hasMore: false,
      );

      await store().loadMore();
      expect(state().items.length, 2);
      expect(state().hasMore, false);
    });

    test('removeLocally removes item by message id', () async {
      fakeRepo.listResult = SavedMessagesPage(
        items: [
          SavedMessageItem(
            message: ConversationMessageSummary(
              id: 'msg-1',
              content: 'Hello',
              createdAt: DateTime(2026, 4, 21),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch1',
          ),
          SavedMessageItem(
            message: ConversationMessageSummary(
              id: 'msg-2',
              content: 'World',
              createdAt: DateTime(2026, 4, 21),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch1',
          ),
        ],
        hasMore: false,
      );

      await store().load();
      store().removeLocally('msg-1');

      expect(state().items.length, 1);
      expect(state().items.first.message.id, 'msg-2');
    });
  });
}

class _FakeSavedMessagesRepository implements SavedMessagesRepository {
  SavedMessagesPage? listResult;
  bool shouldFail = false;

  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Load failed',
        causeType: 'test',
      );
    }
    return listResult ?? const SavedMessagesPage(items: [], hasMore: false);
  }

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Save failed',
        causeType: 'test',
      );
    }
  }

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Unsave failed',
        causeType: 'test',
      );
    }
  }

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Check failed',
        causeType: 'test',
      );
    }
    return {};
  }
}
