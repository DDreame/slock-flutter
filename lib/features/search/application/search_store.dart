import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/data/search_repository_provider.dart';

final currentSearchServerIdProvider = Provider<ServerScopeId>((ref) {
  throw UnimplementedError(
    'currentSearchServerIdProvider must be overridden.',
  );
});

final searchNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final searchLocalMidnightUtcProvider = Provider<DateTime Function(DateTime)>(
  (ref) => computeSearchLocalMidnightUtc,
);

DateTime computeSearchLocalMidnightUtc(
  DateTime localNow, {
  DateTime Function(int year, int month, int day)? localDate,
}) {
  final createLocalDate = localDate ?? DateTime.new;
  return createLocalDate(localNow.year, localNow.month, localNow.day).toUtc();
}

final searchStoreProvider =
    NotifierProvider.autoDispose<SearchStore, SearchState>(
  SearchStore.new,
  dependencies: [currentSearchServerIdProvider],
);

class SearchStore extends AutoDisposeNotifier<SearchState> {
  Timer? _debounce;
  CancelToken? _searchCancelToken;
  CancelToken? _loadMoreCancelToken;
  int _searchRequestToken = 0;
  int _loadMoreRequestToken = 0;

  @override
  SearchState build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _cancelInFlightSearch();
      _cancelInFlightLoadMore();
    });
    return const SearchState();
  }

  void updateQuery(String query) {
    _debounce?.cancel();
    _searchRequestToken++; // invalidate any in-flight search for the old query
    _loadMoreRequestToken++; // invalidate pagination for the old query
    _cancelInFlightSearch();
    _cancelInFlightLoadMore();
    state = state.copyWith(query: query);

    if (query.trim().isEmpty) {
      final currentScope = state.scope;
      state = SearchState(scope: currentScope);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), search);
  }

  void clear() {
    _debounce?.cancel();
    _searchRequestToken++; // invalidate any in-flight search
    _loadMoreRequestToken++; // invalidate any in-flight pagination
    _cancelInFlightSearch();
    _cancelInFlightLoadMore();
    state = const SearchState();
  }

  /// Switch the active scope tab.
  void setScope(SearchScope scope) {
    state = state.copyWith(scope: scope);
  }

  /// Set sender filter and re-search (INV-SEARCH-1).
  void setSenderFilter(String? senderId) {
    state = senderId == null
        ? state.copyWith(clearSenderFilter: true, remoteResults: const [])
        : state.copyWith(senderFilter: senderId, remoteResults: const []);
    _scheduleSearch();
  }

  /// Set sort order and re-search (INV-SEARCH-1).
  void setSortBy(SearchSortBy sortBy) {
    state = state.copyWith(sortBy: sortBy, remoteResults: const []);
    _scheduleSearch();
  }

  /// Set channel filter and re-search (INV-SEARCH-1).
  void setChannelFilter(String? channelId) {
    state = channelId == null
        ? state.copyWith(clearChannelFilter: true, remoteResults: const [])
        : state.copyWith(channelFilter: channelId, remoteResults: const []);
    _scheduleSearch();
  }

  /// Set date range filter and re-search (#736).
  void setDateRange(SearchDateRange dateRange) {
    state = state.copyWith(dateRange: dateRange, remoteResults: const []);
    _scheduleSearch();
  }

  /// Reset all filters to defaults and re-search (INV-SEARCH-3).
  void clearFilters() {
    state = state.copyWith(
      clearSenderFilter: true,
      sortBy: SearchSortBy.newest,
      clearChannelFilter: true,
      dateRange: SearchDateRange.all,
      remoteResults: const [],
    );
    _scheduleSearch();
  }

  Future<void> retry() => search();

  void _cancelInFlightSearch() {
    final cancelToken = _searchCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('superseded search request');
    }
    _searchCancelToken = null;
  }

  void _cancelInFlightLoadMore() {
    final cancelToken = _loadMoreCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('superseded load more request');
    }
    _loadMoreCancelToken = null;
  }

  bool get _hasRemoteRequestInFlight =>
      _searchCancelToken != null || _loadMoreCancelToken != null;

  void _finishSearchRequest(CancelToken cancelToken) {
    if (_searchCancelToken == cancelToken) _searchCancelToken = null;
  }

  void _finishLoadMoreRequest(CancelToken cancelToken) {
    if (_loadMoreCancelToken == cancelToken) _loadMoreCancelToken = null;
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _searchRequestToken++;
    _loadMoreRequestToken++;
    _cancelInFlightSearch();
    _cancelInFlightLoadMore();
    if (state.query.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 300), search);
  }

  /// Load more results at the current offset (INV-SEARCH-4).
  Future<void> loadMore() async {
    final query = state.query.trim();
    if (query.isEmpty || !state.hasMore) return;

    final token = ++_loadMoreRequestToken;
    _cancelInFlightLoadMore();
    final cancelToken = CancelToken();
    _loadMoreCancelToken = cancelToken;
    final serverId = ref.read(currentSearchServerIdProvider);
    final offset = state.remoteResults.length;

    state = state.copyWith(isRemoteSearching: true);

    try {
      final repo = ref.read(searchRepositoryProvider);
      final page = await repo.searchMessages(
        serverId,
        query,
        senderId: state.senderFilter,
        sortBy: state.sortBy,
        channelId: state.channelFilter,
        after: _computeAfterDate(state.dateRange),
        offset: offset,
        cancelToken: cancelToken,
      );
      if (_loadMoreRequestToken != token) return;
      _finishLoadMoreRequest(cancelToken);
      state = state.copyWith(
        remoteResults: [...state.remoteResults, ...page.messages],
        hasMore: page.hasMore,
        isRemoteSearching: _hasRemoteRequestInFlight,
      );
    } on AppFailure catch (failure) {
      if (_loadMoreRequestToken != token) return;
      _finishLoadMoreRequest(cancelToken);
      state = state.copyWith(
        isRemoteSearching: _hasRemoteRequestInFlight,
        failure: failure,
      );
    } on DioException catch (error) {
      if (_loadMoreRequestToken != token) return;
      _finishLoadMoreRequest(cancelToken);
      state = state.copyWith(
        isRemoteSearching: _hasRemoteRequestInFlight,
      );
      if (error.type != DioExceptionType.cancel) rethrow;
    }
  }

  Future<void> search() async {
    _debounce?.cancel();
    _debounce = null;
    final query = state.query.trim();
    if (query.isEmpty) return;

    final token = ++_searchRequestToken;
    _cancelInFlightSearch();
    _loadMoreRequestToken++;
    _cancelInFlightLoadMore();
    final cancelToken = CancelToken();
    _searchCancelToken = cancelToken;
    final serverId = ref.read(currentSearchServerIdProvider);
    state = state.copyWith(
      status: SearchStatus.searching,
      isRemoteSearching: true,
      clearFailure: true,
    );

    // --- Local search: messages ---
    final localStore = ref.read(conversationLocalStoreProvider);
    final localMessages = await localStore.searchMessages(
      serverId.value,
      query,
    );

    // --- Local search: conversation summaries (channels + DMs) ---
    final localSummaries = await localStore.searchConversationSummaries(
      serverId.value,
      query,
    );

    // --- Local search: identities (contacts) ---
    final localIdentities = await localStore.searchIdentities(
      serverId.value,
      query,
    );

    // Build message results from local messages.
    final localResults = <SearchResultMessage>[
      for (final message in localMessages)
        SearchResultMessage(
          message: ConversationMessageSummary(
            id: message.messageId,
            content: message.content,
            createdAt: message.createdAt,
            senderType: message.senderType,
            messageType: message.messageType,
            senderName: message.senderName,
            seq: message.seq,
          ),
          channelId: message.conversationId,
        ),
    ];

    // Build channel results from conversation summaries.
    final channelResults = <SearchChannelResult>[
      for (final summary in localSummaries)
        SearchChannelResult(
          channelId: summary.conversationId,
          channelName: summary.title,
          surface: summary.surface,
          lastMessagePreview: summary.lastMessagePreview,
          lastActivityAt: summary.lastActivityAt,
        ),
    ];

    // Build contact results from identities.
    final contactResults = <SearchContactResult>[
      for (final identity in localIdentities)
        SearchContactResult(
          identityId: identity.identityId,
          displayName: identity.displayName,
          avatarUrl: identity.avatarUrl,
        ),
    ];

    if (_searchRequestToken != token) return;
    state = state.copyWith(
      localResults: localResults,
      channelResults: channelResults,
      contactResults: contactResults,
      status: SearchStatus.searching,
    );

    // --- Remote search: messages ---
    try {
      final repo = ref.read(searchRepositoryProvider);
      final page = await repo.searchMessages(
        serverId,
        query,
        senderId: state.senderFilter,
        sortBy: state.sortBy,
        channelId: state.channelFilter,
        after: _computeAfterDate(state.dateRange),
        cancelToken: cancelToken,
      );
      if (_searchRequestToken != token) return;
      _finishSearchRequest(cancelToken);
      state = state.copyWith(
        remoteResults: page.messages,
        hasMore: page.hasMore,
        isRemoteSearching: _hasRemoteRequestInFlight,
        status: SearchStatus.success,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (_searchRequestToken != token) return;
      _finishSearchRequest(cancelToken);
      state = state.copyWith(
        isRemoteSearching: _hasRemoteRequestInFlight,
        status: localResults.isNotEmpty ||
                channelResults.isNotEmpty ||
                contactResults.isNotEmpty
            ? SearchStatus.success
            : SearchStatus.failure,
        failure: failure,
      );
    } on DioException catch (error) {
      if (_searchRequestToken != token) return;
      _finishSearchRequest(cancelToken);
      state = state.copyWith(
        isRemoteSearching: _hasRemoteRequestInFlight,
      );
      if (error.type != DioExceptionType.cancel) rethrow;
    }
  }

  /// Compute the `after` ISO8601 date from the date range filter (#736).
  ///
  /// Returns `null` for [SearchDateRange.all] (no time restriction).
  String? _computeAfterDate(SearchDateRange range) {
    final now = ref.read(searchNowProvider)();
    final localNow = now.isUtc ? now.toLocal() : now;
    final localMidnightUtc = ref.read(searchLocalMidnightUtcProvider)(localNow);
    switch (range) {
      case SearchDateRange.all:
        return null;
      case SearchDateRange.today:
        return localMidnightUtc.toIso8601String();
      case SearchDateRange.last7days:
        return localMidnightUtc
            .subtract(const Duration(days: 6))
            .toIso8601String();
      case SearchDateRange.last30days:
        return localMidnightUtc
            .subtract(const Duration(days: 30))
            .toIso8601String();
    }
  }
}
