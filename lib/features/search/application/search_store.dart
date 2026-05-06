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

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void updateQuery(String query) {
    _debounce?.cancel();
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
    state = const SearchState();
  }

  /// Switch the active scope tab.
  void setScope(SearchScope scope) {
    state = state.copyWith(scope: scope);
  }

  Future<void> retry() => search();

  Future<void> search() async {
    final query = state.query.trim();
    if (query.isEmpty) return;

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

    if (state.query.trim() != query) return;
    state = state.copyWith(
      localResults: localResults,
      channelResults: channelResults,
      contactResults: contactResults,
      status: SearchStatus.searching,
    );

    // --- Remote search: messages ---
    try {
      final repo = ref.read(searchRepositoryProvider);
      final page = await repo.searchMessages(serverId, query);
      if (state.query.trim() != query) return;
      state = state.copyWith(
        remoteResults: page.messages,
        hasMore: page.hasMore,
        isRemoteSearching: false,
        status: SearchStatus.success,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (state.query.trim() != query) return;
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
