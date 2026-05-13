import 'dart:async';

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
  int _requestToken = 0;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void updateQuery(String query) {
    _debounce?.cancel();
    _requestToken++; // invalidate any in-flight search for the old query
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
    state = const SearchState();
  }

  /// Switch the active scope tab.
  void setScope(SearchScope scope) {
    state = state.copyWith(scope: scope);
  }

  /// Set sender filter and re-search (INV-SEARCH-1).
  Future<void> setSenderFilter(String? senderId) async {
    state = senderId == null
        ? state.copyWith(clearSenderFilter: true, remoteResults: const [])
        : state.copyWith(senderFilter: senderId, remoteResults: const []);
    if (state.query.trim().isNotEmpty) await search();
  }

  /// Set sort order and re-search (INV-SEARCH-1).
  Future<void> setSortBy(SearchSortBy sortBy) async {
    state = state.copyWith(sortBy: sortBy, remoteResults: const []);
    if (state.query.trim().isNotEmpty) await search();
  }

  /// Set channel filter and re-search (INV-SEARCH-1).
  Future<void> setChannelFilter(String? channelId) async {
    state = channelId == null
        ? state.copyWith(clearChannelFilter: true, remoteResults: const [])
        : state.copyWith(channelFilter: channelId, remoteResults: const []);
    if (state.query.trim().isNotEmpty) await search();
  }

  /// Reset all filters to defaults and re-search (INV-SEARCH-3).
  Future<void> clearFilters() async {
    state = state.copyWith(
      clearSenderFilter: true,
      sortBy: SearchSortBy.newest,
      clearChannelFilter: true,
      remoteResults: const [],
    );
    if (state.query.trim().isNotEmpty) await search();
  }

  Future<void> retry() => search();

  /// Load more results at the current offset (INV-SEARCH-4).
  Future<void> loadMore() async {
    final query = state.query.trim();
    if (query.isEmpty || !state.hasMore) return;

    final token = ++_requestToken;
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
        offset: offset,
      );
      if (_requestToken != token) return;
      state = state.copyWith(
        remoteResults: [...state.remoteResults, ...page.messages],
        hasMore: page.hasMore,
        isRemoteSearching: false,
      );
    } on AppFailure catch (failure) {
      if (_requestToken != token) return;
      state = state.copyWith(
        isRemoteSearching: false,
        failure: failure,
      );
    }
  }

  Future<void> search() async {
    final query = state.query.trim();
    if (query.isEmpty) return;

    final token = ++_requestToken;
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
      );
      if (_requestToken != token) return;
      state = state.copyWith(
        remoteResults: page.messages,
        hasMore: page.hasMore,
        isRemoteSearching: false,
        status: SearchStatus.success,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (_requestToken != token) return;
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
}
