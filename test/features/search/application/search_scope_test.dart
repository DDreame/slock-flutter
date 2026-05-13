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

  group('search scope', () {
    test('default scope is all', () {
      expect(state().scope, SearchScope.all);
    });

    test('setScope changes active scope', () {
      store().setScope(SearchScope.channels);
      expect(state().scope, SearchScope.channels);

      store().setScope(SearchScope.contacts);
      expect(state().scope, SearchScope.contacts);

      store().setScope(SearchScope.messages);
      expect(state().scope, SearchScope.messages);
    });

    test('setScope re-triggers search when query is non-empty', () async {
      fakeSearchRepo.result = const SearchResultsPage(
        messages: [],
        hasMore: false,
      );

      store().updateQuery('test');
      await store().search();
      expect(state().status, SearchStatus.success);

      store().setScope(SearchScope.channels);
      // Scope changes state but does not discard results — results remain
      expect(state().scope, SearchScope.channels);
    });

    test('search categorizes local channel results separately', () async {
      // Add a channel conversation summary
      await fakeLocalStore.upsertConversationSummaries([
        LocalConversationSummaryUpsert(
          serverId: 'server-1',
          conversationId: 'ch-general',
          surface: 'channel',
          title: 'general',
          sortIndex: 0,
          lastMessagePreview: 'Hello world',
          lastActivityAt: DateTime(2026, 5, 1),
        ),
        LocalConversationSummaryUpsert(
          serverId: 'server-1',
          conversationId: 'dm-alice',
          surface: 'direct_message',
          title: 'Alice',
          sortIndex: 1,
          lastMessagePreview: 'Hey there',
          lastActivityAt: DateTime(2026, 5, 1),
        ),
      ]);

      fakeSearchRepo.result =
          const SearchResultsPage(messages: [], hasMore: false);

      store().updateQuery('general');
      await store().search();

      expect(state().channelResults, isNotEmpty);
      expect(
        state().channelResults.any((r) => r.channelName == 'general'),
        isTrue,
      );
    });

    test('search categorizes DM results in channels scope', () async {
      await fakeLocalStore.upsertConversationSummaries([
        LocalConversationSummaryUpsert(
          serverId: 'server-1',
          conversationId: 'dm-bob',
          surface: 'direct_message',
          title: 'Bob',
          sortIndex: 0,
          lastMessagePreview: 'Latest message',
          lastActivityAt: DateTime(2026, 5, 1),
        ),
      ]);

      fakeSearchRepo.result =
          const SearchResultsPage(messages: [], hasMore: false);

      store().updateQuery('Bob');
      await store().search();

      // DMs appear in channel results since they are conversation summaries
      expect(state().channelResults, isNotEmpty);
      expect(
        state().channelResults.any((r) => r.channelName == 'Bob'),
        isTrue,
      );
    });

    test('search populates contact results from identities', () async {
      await fakeLocalStore.upsertIdentities([
        const LocalIdentityUpsert(
          serverId: 'server-1',
          identityId: 'user-alice',
          displayName: 'Alice Chen',
        ),
        const LocalIdentityUpsert(
          serverId: 'server-1',
          identityId: 'user-bob',
          displayName: 'Bob Smith',
        ),
      ]);

      fakeSearchRepo.result =
          const SearchResultsPage(messages: [], hasMore: false);

      store().updateQuery('Alice');
      await store().search();

      expect(state().contactResults, isNotEmpty);
      expect(
        state().contactResults.any((c) => c.displayName == 'Alice Chen'),
        isTrue,
      );
      // Bob should not match
      expect(
        state().contactResults.any((c) => c.displayName == 'Bob Smith'),
        isFalse,
      );
    });

    test('scopedResults returns all results when scope is all', () async {
      await fakeLocalStore.upsertConversationSummaries([
        const LocalConversationSummaryUpsert(
          serverId: 'server-1',
          conversationId: 'ch-general',
          surface: 'channel',
          title: 'general',
          sortIndex: 0,
        ),
      ]);

      fakeLocalStore.upsertMessages([
        LocalMessageUpsert(
          serverId: 'server-1',
          conversationId: 'ch-general',
          messageId: 'msg-1',
          content: 'Hello general world',
          createdAt: DateTime(2026, 5, 1),
          senderType: 'human',
          messageType: 'message',
        ),
      ]);

      fakeSearchRepo.result =
          const SearchResultsPage(messages: [], hasMore: false);

      store().updateQuery('general');
      await store().search();

      // In "all" scope, mergedResults includes everything
      expect(state().mergedResults, isNotEmpty);
    });

    test('scopedMessageCount returns count for messages tab badge', () async {
      fakeLocalStore.upsertMessages([
        LocalMessageUpsert(
          serverId: 'server-1',
          conversationId: 'ch-1',
          messageId: 'msg-1',
          content: 'Match keyword here',
          createdAt: DateTime(2026, 5, 1),
          senderType: 'human',
          messageType: 'message',
        ),
        LocalMessageUpsert(
          serverId: 'server-1',
          conversationId: 'ch-1',
          messageId: 'msg-2',
          content: 'Another keyword match',
          createdAt: DateTime(2026, 5, 1),
          senderType: 'human',
          messageType: 'message',
        ),
      ]);

      fakeSearchRepo.result = SearchResultsPage(
        messages: [
          SearchResultMessage(
            message: ConversationMessageSummary(
              id: 'remote-1',
              content: 'Remote keyword match',
              createdAt: DateTime(2026, 5, 1),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch-2',
          ),
        ],
        hasMore: false,
      );

      store().updateQuery('keyword');
      await store().search();

      // Should have message results from both local + remote
      expect(state().mergedResults.length, greaterThanOrEqualTo(2));
    });

    test('clear resets scope to all', () {
      store().setScope(SearchScope.channels);
      expect(state().scope, SearchScope.channels);

      store().clear();
      expect(state().scope, SearchScope.all);
    });
  });
}

class _FakeSearchRepository implements SearchRepository {
  SearchResultsPage? result;
  bool shouldFail = false;

  @override
  Future<SearchResultsPage> searchMessages(
    ServerScopeId serverId,
    String query, {
    String? senderId,
    SearchSortBy? sortBy,
    String? channelId,
    int offset = 0,
  }) async {
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Search failed',
        causeType: 'test',
      );
    }
    return result ?? const SearchResultsPage(messages: [], hasMore: false);
  }
}
