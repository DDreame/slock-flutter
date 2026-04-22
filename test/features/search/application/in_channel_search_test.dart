import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

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
    ConversationMessageSummary(
      id: 'msg-3',
      content: 'Hello again',
      createdAt: DateTime.parse('2026-04-21T10:02:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: 3,
    ),
  ];

  ProviderContainer createLoadedContainer() {
    final ingress = RealtimeReductionIngress();
    final fakeLocalStore = FakeConversationLocalStore();
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
      ],
    );
    return container;
  }

  group('in-channel search', () {
    test('toggleSearch activates search mode', () async {
      final container = createLoadedContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();

      container.read(conversationDetailStoreProvider.notifier).toggleSearch();
      final state = container.read(conversationDetailStoreProvider);
      expect(state.isSearchActive, isTrue);
      expect(state.searchQuery, '');
      expect(state.searchMatchIds, isEmpty);
    });

    test('toggleSearch deactivates search and clears state', () async {
      final container = createLoadedContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();

      final store = container.read(conversationDetailStoreProvider.notifier);
      store.toggleSearch();
      store.updateSearchQuery('Hello');
      store.toggleSearch();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.isSearchActive, isFalse);
      expect(state.searchQuery, '');
      expect(state.searchMatchIds, isEmpty);
      expect(state.currentSearchMatchIndex, -1);
    });

    test('updateSearchQuery finds matching messages', () async {
      final container = createLoadedContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();

      container
          .read(conversationDetailStoreProvider.notifier)
          .updateSearchQuery('Hello');
      final state = container.read(conversationDetailStoreProvider);
      expect(state.searchMatchIds, ['msg-1', 'msg-3']);
      expect(state.currentSearchMatchIndex, 0);
    });

    test('updateSearchQuery is case insensitive', () async {
      final container = createLoadedContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();

      container
          .read(conversationDetailStoreProvider.notifier)
          .updateSearchQuery('hello');
      final state = container.read(conversationDetailStoreProvider);
      expect(state.searchMatchIds, ['msg-1', 'msg-3']);
    });

    test('updateSearchQuery with no matches returns empty', () async {
      final container = createLoadedContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();

      container
          .read(conversationDetailStoreProvider.notifier)
          .updateSearchQuery('xyz');
      final state = container.read(conversationDetailStoreProvider);
      expect(state.searchMatchIds, isEmpty);
      expect(state.currentSearchMatchIndex, -1);
    });

    test('updateSearchQuery with empty clears matches', () async {
      final container = createLoadedContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();

      final store = container.read(conversationDetailStoreProvider.notifier);
      store.updateSearchQuery('Hello');
      store.updateSearchQuery('');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.searchMatchIds, isEmpty);
      expect(state.currentSearchMatchIndex, -1);
    });

    test('nextSearchResult cycles forward', () async {
      final container = createLoadedContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();

      final store = container.read(conversationDetailStoreProvider.notifier);
      store.updateSearchQuery('Hello');
      expect(
          container
              .read(conversationDetailStoreProvider)
              .currentSearchMatchIndex,
          0);

      store.nextSearchResult();
      expect(
          container
              .read(conversationDetailStoreProvider)
              .currentSearchMatchIndex,
          1);

      store.nextSearchResult();
      expect(
          container
              .read(conversationDetailStoreProvider)
              .currentSearchMatchIndex,
          0);
    });

    test('previousSearchResult cycles backward', () async {
      final container = createLoadedContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();

      final store = container.read(conversationDetailStoreProvider.notifier);
      store.updateSearchQuery('Hello');
      expect(
          container
              .read(conversationDetailStoreProvider)
              .currentSearchMatchIndex,
          0);

      store.previousSearchResult();
      expect(
          container
              .read(conversationDetailStoreProvider)
              .currentSearchMatchIndex,
          1);
    });

    test('next/previous on empty matches does nothing', () async {
      final container = createLoadedContainer();
      addTearDown(container.dispose);
      await container.read(conversationDetailStoreProvider.notifier).load();

      final store = container.read(conversationDetailStoreProvider.notifier);
      store.updateSearchQuery('xyz');
      store.nextSearchResult();
      store.previousSearchResult();
      expect(
          container
              .read(conversationDetailStoreProvider)
              .currentSearchMatchIndex,
          -1);
    });
  });
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
