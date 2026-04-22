import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/application/search_store.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/data/search_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

import '../../../core/local_data/fake_conversation_local_store.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  late FakeConversationLocalStore fakeLocalStore;
  late _FakeSearchRepository fakeSearchRepo;
  late ProviderContainer container;

  setUp(() {
    fakeLocalStore = FakeConversationLocalStore();
    fakeSearchRepo = _FakeSearchRepository();
    container = ProviderContainer(overrides: [
      currentSearchServerIdProvider.overrideWithValue(serverId),
      conversationLocalStoreProvider.overrideWithValue(fakeLocalStore),
      searchRepositoryProvider.overrideWithValue(fakeSearchRepo),
    ]);
  });

  tearDown(() => container.dispose());

  SearchStore store() => container.read(searchStoreProvider.notifier);
  SearchState state() => container.read(searchStoreProvider);

  group('search store', () {
    test('initial state is idle', () {
      expect(state().status, SearchStatus.idle);
      expect(state().query, '');
      expect(state().mergedResults, isEmpty);
    });

    test('updateQuery with empty string resets to idle', () {
      store().updateQuery('');
      expect(state().status, SearchStatus.idle);
    });

    test('clear resets state', () {
      store().updateQuery('test');
      store().clear();
      expect(state().status, SearchStatus.idle);
      expect(state().query, '');
    });

    test('search merges local and remote results', () async {
      fakeLocalStore.upsertMessages([
        LocalMessageUpsert(
          serverId: 'server-1',
          conversationId: 'ch1',
          messageId: 'msg-1',
          content: 'Hello world',
          createdAt: DateTime(2026, 4, 21),
          senderType: 'human',
          messageType: 'message',
        ),
      ]);

      fakeSearchRepo.result = SearchResultsPage(
        messages: [
          SearchResultMessage(
            message: ConversationMessageSummary(
              id: 'remote-1',
              content: 'Hello from remote',
              createdAt: DateTime.parse('2026-04-21T10:00:00Z'),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch2',
          ),
        ],
        hasMore: false,
      );

      store().updateQuery('Hello');
      expect(state().query, 'Hello');

      await store().search();

      expect(state().status, SearchStatus.success);
      expect(state().mergedResults, isNotEmpty);
    });

    test('remote failure falls back to local results', () async {
      fakeLocalStore.upsertMessages([
        LocalMessageUpsert(
          serverId: 'server-1',
          conversationId: 'ch1',
          messageId: 'msg-1',
          content: 'Local match',
          createdAt: DateTime(2026, 4, 21),
          senderType: 'human',
          messageType: 'message',
        ),
      ]);

      fakeSearchRepo.shouldFail = true;

      store().updateQuery('Local');
      await store().search();

      expect(state().status, SearchStatus.success);
      expect(state().localResults, isNotEmpty);
    });

    test('remote failure with no local results shows failure', () async {
      fakeSearchRepo.shouldFail = true;

      store().updateQuery('nothing');
      await store().search();

      expect(state().status, SearchStatus.failure);
    });
  });
}

class _FakeSearchRepository implements SearchRepository {
  SearchResultsPage? result;
  bool shouldFail = false;

  @override
  Future<SearchResultsPage> searchMessages(
    ServerScopeId serverId,
    String query,
  ) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Search failed',
        causeType: 'test',
      );
    }
    return result ?? const SearchResultsPage(messages: [], hasMore: false);
  }
}
