import 'dart:async';

import 'package:dio/dio.dart';
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
  late ProviderSubscription<SearchState> subscription;

  setUp(() {
    fakeLocalStore = FakeConversationLocalStore();
    fakeSearchRepo = _FakeSearchRepository();
    container = ProviderContainer(overrides: [
      currentSearchServerIdProvider.overrideWithValue(serverId),
      conversationLocalStoreProvider.overrideWithValue(fakeLocalStore),
      searchRepositoryProvider.overrideWithValue(fakeSearchRepo),
    ]);
    subscription = container.listen<SearchState>(
      searchStoreProvider,
      (_, __) {},
      fireImmediately: true,
    );
  });

  tearDown(() {
    subscription.close();
    container.dispose();
  });

  SearchStore store() => container.read(searchStoreProvider.notifier);
  SearchState state() => container.read(searchStoreProvider);
  Future<void> settleDebouncedSearch() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (var i = 0; i < 10 && fakeSearchRepo.lastCallParams == null; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

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

    test('retry re-executes search and recovers from failure', () async {
      fakeSearchRepo.shouldFail = true;

      store().updateQuery('retry-me');
      await store().search();

      expect(state().status, SearchStatus.failure);

      fakeSearchRepo.shouldFail = false;
      fakeSearchRepo.result = SearchResultsPage(
        messages: [
          SearchResultMessage(
            message: ConversationMessageSummary(
              id: 'recovered-1',
              content: 'Recovered',
              createdAt: DateTime.parse('2026-04-21T10:00:00Z'),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch1',
          ),
        ],
        hasMore: false,
      );

      await store().retry();

      expect(state().status, SearchStatus.success);
      expect(state().mergedResults, isNotEmpty);
    });
  });

  // -----------------------------------------------------------------
  // Stale-query race guard regression
  // -----------------------------------------------------------------

  test('query change during in-flight search discards old results', () async {
    final completer = Completer<SearchResultsPage>();
    fakeSearchRepo.completerOverride = completer;

    store().updateQuery('abc');
    // Start the search manually (bypassing debounce).
    final searchFuture = store().search();

    // While search for "abc" is in flight, user types "abcd".
    store().updateQuery('abcd');

    // Complete the old search with "abc" results.
    completer.complete(SearchResultsPage(
      messages: [
        SearchResultMessage(
          message: ConversationMessageSummary(
            id: 'stale-1',
            content: 'Stale result for abc',
            createdAt: DateTime.parse('2026-04-21T10:00:00Z'),
            senderType: 'human',
            messageType: 'message',
          ),
          channelId: 'ch1',
        ),
      ],
      hasMore: false,
    ));

    await searchFuture;

    // The old "abc" results must NOT be written into state
    // because updateQuery("abcd") bumped _requestToken.
    expect(state().remoteResults, isEmpty,
        reason: 'Stale results from old query must be discarded');
  });

  // -----------------------------------------------------------------
  // Filter & pagination (INV-SEARCH)
  // -----------------------------------------------------------------

  group('search filters', () {
    test(
        'setSenderFilter triggers debounced search with senderId param '
        '(INV-SEARCH-1)', () async {
      fakeSearchRepo.result = const SearchResultsPage(
        messages: [],
        hasMore: false,
      );

      store().updateQuery('hello');
      await store().search();
      fakeSearchRepo.lastCallParams = null; // reset

      store().setSenderFilter('user-42');

      expect(state().senderFilter, 'user-42');
      expect(fakeSearchRepo.lastCallParams, isNull,
          reason: 'Filter changes should use the same debounce as query input');
      await settleDebouncedSearch();
      expect(fakeSearchRepo.lastCallParams?.senderId, 'user-42',
          reason: 'INV-SEARCH-1: setSenderFilter must trigger search '
              'with senderId');
    });

    test(
        'setSortBy triggers debounced search with sortBy param '
        '(INV-SEARCH-1)', () async {
      fakeSearchRepo.result = const SearchResultsPage(
        messages: [],
        hasMore: false,
      );

      store().updateQuery('hello');
      await store().search();
      fakeSearchRepo.lastCallParams = null;

      store().setSortBy(SearchSortBy.oldest);

      expect(state().sortBy, SearchSortBy.oldest);
      expect(fakeSearchRepo.lastCallParams, isNull,
          reason: 'Filter changes should not bypass debounce');
      await settleDebouncedSearch();
      expect(fakeSearchRepo.lastCallParams?.sortBy, SearchSortBy.oldest,
          reason: 'INV-SEARCH-1: setSortBy must trigger search '
              'with sortBy');
    });

    test('clearFilters resets all filters and searches (INV-SEARCH-3)',
        () async {
      fakeSearchRepo.result = const SearchResultsPage(
        messages: [],
        hasMore: false,
      );

      store().updateQuery('hello');
      await store().search();

      store().setSenderFilter('user-42');
      store().setChannelFilter('general');
      store().setSortBy(SearchSortBy.oldest);

      expect(state().senderFilter, 'user-42');
      expect(state().channelFilter, 'general');
      expect(state().sortBy, SearchSortBy.oldest);

      fakeSearchRepo.lastCallParams = null;
      store().clearFilters();

      expect(state().senderFilter, isNull,
          reason: 'INV-SEARCH-3: senderFilter reset');
      expect(state().channelFilter, isNull,
          reason: 'INV-SEARCH-3: channelFilter reset');
      expect(state().sortBy, SearchSortBy.newest,
          reason: 'INV-SEARCH-3: sortBy reset to newest');
      expect(fakeSearchRepo.lastCallParams, isNull,
          reason: 'clearFilters should debounce the follow-up search');
      await settleDebouncedSearch();
      expect(fakeSearchRepo.lastCallParams?.senderId, isNull);
      expect(fakeSearchRepo.lastCallParams?.sortBy, SearchSortBy.newest);
      expect(fakeSearchRepo.lastCallParams?.channelId, isNull);
    });

    test('filter change during in-flight search discards old remote results',
        () async {
      final completer = Completer<SearchResultsPage>();
      fakeSearchRepo.completerOverride = completer;
      fakeSearchRepo.onSearchCall = Completer<void>();

      store().updateQuery('hello');
      final searchFuture = store().search();
      await fakeSearchRepo.onSearchCall!.future;

      final firstCancelToken = fakeSearchRepo.cancelTokens.single;
      store().setSenderFilter('user-42');

      completer.complete(SearchResultsPage(
        messages: [
          SearchResultMessage(
            message: ConversationMessageSummary(
              id: 'stale-filter-result',
              content: 'Stale unfiltered result',
              createdAt: DateTime.parse('2026-04-21T10:00:00Z'),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch1',
          ),
        ],
        hasMore: false,
      ));

      await searchFuture;

      expect(firstCancelToken?.isCancelled, isTrue);
      expect(state().senderFilter, 'user-42');
      expect(state().remoteResults, isEmpty,
          reason:
              'Stale results from the pre-filter request must be discarded');
    });

    test('loadMore appends results at current offset (INV-SEARCH-4)', () async {
      final page1 = SearchResultsPage(
        messages: [
          SearchResultMessage(
            message: ConversationMessageSummary(
              id: 'msg-1',
              content: 'First',
              createdAt: DateTime.parse('2026-04-21T10:00:00Z'),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch1',
          ),
        ],
        hasMore: true,
      );

      final page2 = SearchResultsPage(
        messages: [
          SearchResultMessage(
            message: ConversationMessageSummary(
              id: 'msg-2',
              content: 'Second',
              createdAt: DateTime.parse('2026-04-21T11:00:00Z'),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch1',
          ),
        ],
        hasMore: false,
      );

      fakeSearchRepo.result = page1;

      store().updateQuery('test');
      await store().search();

      expect(state().remoteResults, hasLength(1));
      expect(state().hasMore, isTrue);

      fakeSearchRepo.result = page2;
      await store().loadMore();

      expect(state().remoteResults, hasLength(2));
      expect(state().remoteResults[0].message.id, 'msg-1');
      expect(state().remoteResults[1].message.id, 'msg-2');
      expect(state().hasMore, isFalse,
          reason: 'INV-SEARCH-4: hasMore should update after last page');
      expect(fakeSearchRepo.lastCallParams?.offset, 1,
          reason: 'INV-SEARCH-4: offset should equal existing result count');
    });

    test('superseded search cancels previous remote request', () async {
      final firstCompleter = Completer<SearchResultsPage>();
      fakeSearchRepo.completerOverride = firstCompleter;
      fakeSearchRepo.onSearchCall = Completer<void>();

      store().updateQuery('first');
      final firstSearch = store().search();
      await fakeSearchRepo.onSearchCall!.future;

      final firstCancelToken = fakeSearchRepo.cancelTokens.single;
      expect(firstCancelToken, isNotNull);
      expect(firstCancelToken!.isCancelled, isFalse);

      fakeSearchRepo.completerOverride = null;
      fakeSearchRepo.result = const SearchResultsPage(
        messages: [],
        hasMore: false,
      );

      store().updateQuery('second');
      await store().search();

      expect(firstCancelToken.isCancelled, isTrue);
      expect(fakeSearchRepo.queries, ['first', 'second']);

      firstCompleter.complete(
        const SearchResultsPage(messages: [], hasMore: false),
      );
      await firstSearch;
    });
  });
}

/// Captures the parameters from the last `searchMessages` call.
class _SearchCallParams {
  const _SearchCallParams({
    this.senderId,
    this.sortBy,
    this.channelId,
    this.offset = 0,
  });

  final String? senderId;
  final SearchSortBy? sortBy;
  final String? channelId;
  final int offset;
}

class _FakeSearchRepository implements SearchRepository {
  SearchResultsPage? result;
  bool shouldFail = false;
  _SearchCallParams? lastCallParams;
  final queries = <String>[];
  final cancelTokens = <CancelToken?>[];
  Completer<void>? onSearchCall;

  /// When set, `searchMessages` awaits this completer instead of returning
  /// immediately. Used to simulate in-flight requests that haven't completed.
  Completer<SearchResultsPage>? completerOverride;

  @override
  Future<SearchResultsPage> searchMessages(
    ServerScopeId serverId,
    String query, {
    String? senderId,
    SearchSortBy? sortBy,
    String? channelId,
    String? after,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    queries.add(query);
    cancelTokens.add(cancelToken);
    onSearchCall?.complete();
    onSearchCall = null;
    lastCallParams = _SearchCallParams(
      senderId: senderId,
      sortBy: sortBy,
      channelId: channelId,
      offset: offset,
    );
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Search failed',
        causeType: 'test',
      );
    }
    if (completerOverride != null) {
      return completerOverride!.future;
    }
    return result ?? const SearchResultsPage(messages: [], hasMore: false);
  }
}
