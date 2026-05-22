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

final searchStoreProvider =
    NotifierProvider.autoDispose<SearchStore, SearchState>(
  SearchStore.new,
  dependencies: [currentSearchServerIdProvider],
);

class SearchStore extends AutoDisposeNotifier<SearchState> {
  Timer? _debounce;
  CancelToken? _remoteCancelToken;
  int _requestToken = 0;

  @override
  SearchState build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _cancelInFlightSearch();
    });
    return const SearchState();
  }

  void updateQuery(String query) {
    _debounce?.cancel();
    _requestToken++; // invalidate any in-flight search for the old query
    _cancelInFlightSearch();
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
    _requestToken++; // invalidate any in-flight search
    _cancelInFlightSearch();
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
    final cancelToken = _remoteCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('superseded search request');
    }
    _remoteCancelToken = null;
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _requestToken++;
    _cancelInFlightSearch();
    if (state.query.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 300), search);
  }

  /// Load more results at the current offset (INV-SEARCH-4).
  Future<void> loadMore() async {
    final query = state.query.trim();
    if (query.isEmpty || !state.hasMore) return;

    final token = ++_requestToken;
    _cancelInFlightSearch();
    final cancelToken = CancelToken();
    _remoteCancelToken = cancelToken;
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
      if (_requestToken != token) return;
      if (_remoteCancelToken == cancelToken) _remoteCancelToken = null;
      state = state.copyWith(
        remoteResults: [...state.remoteResults, ...page.messages],
        hasMore: page.hasMore,
        isRemoteSearching: false,
      );
    } on AppFailure catch (failure) {
      if (_requestToken != token) return;
      if (_remoteCancelToken == cancelToken) _remoteCancelToken = null;
      state = state.copyWith(
        isRemoteSearching: false,
        failure: failure,
      );
    }
  }

  Future<void> search() async {
    _debounce?.cancel();
    _debounce = null;
    final query = state.query.trim();
    if (query.isEmpty) return;

    final token = ++_requestToken;
    _cancelInFlightSearch();
    final cancelToken = CancelToken();
    _remoteCancelToken = cancelToken;
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

    if (_requestToken != token) return;
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
      if (_requestToken != token) return;
      if (_remoteCancelToken == cancelToken) _remoteCancelToken = null;
      state = state.copyWith(
        remoteResults: page.messages,
        hasMore: page.hasMore,
        isRemoteSearching: false,
        status: SearchStatus.success,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (_requestToken != token) return;
      if (_remoteCancelToken == cancelToken) _remoteCancelToken = null;
      state = state.copyWith(
        isRemoteSearching: false,
        status: localResults.isNotEmpty ||
                channelResults.isNotEmpty ||
                contactResults.isNotEmpty
            ? SearchStatus.success
            : SearchStatus.failure,
        failure: failure,
      );
    }
  }

  /// Compute the `after` ISO8601 date from the date range filter (#736).
  ///
  /// Returns `null` for [SearchDateRange.all] (no time restriction).
  static String? _computeAfterDate(SearchDateRange range) {
    final now = DateTime.now().toUtc();
    switch (range) {
      case SearchDateRange.all:
        return null;
      case SearchDateRange.today:
        return DateTime.utc(now.year, now.month, now.day).toIso8601String();
      case SearchDateRange.last7days:
        return DateTime.utc(now.year, now.month, now.day)
            .subtract(const Duration(days: 7))
            .toIso8601String();
      case SearchDateRange.last30days:
        return DateTime.utc(now.year, now.month, now.day)
            .subtract(const Duration(days: 30))
            .toIso8601String();
    }
  }
}
