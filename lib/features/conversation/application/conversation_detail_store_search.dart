part of 'conversation_detail_store.dart';

/// Search-related methods for [ConversationDetailStore].
///
/// Extracted from the monolithic store to improve readability (#640).
mixin _ConversationDetailSearchMixin
    on AutoDisposeNotifier<ConversationDetailState> {
  /// Cached lowercase content map — avoids O(n) String allocations per
  /// keystroke. Invalidated when the message list reference changes.
  List<Object>? _cachedSearchMessages;
  Map<String, String> _lowerContentMap = const {};

  /// Returns the cached lowercase content map, rebuilding only when messages
  /// change (identity check).
  Map<String, String> _getLowerContent() {
    if (!identical(_cachedSearchMessages, state.messages)) {
      _cachedSearchMessages = state.messages;
      _lowerContentMap = {
        for (final m in state.messages) m.id: m.content.toLowerCase(),
      };
    }
    return _lowerContentMap;
  }

  void toggleSearch() {
    if (state.isSearchActive) {
      state = state.copyWith(
        isSearchActive: false,
        searchQuery: '',
        searchMatchIds: const [],
        currentSearchMatchIndex: -1,
      );
    } else {
      state = state.copyWith(isSearchActive: true);
    }
  }

  void updateSearchQuery(String query) {
    if (query.isEmpty) {
      state = state.copyWith(
        searchQuery: '',
        searchMatchIds: const [],
        currentSearchMatchIndex: -1,
      );
      return;
    }

    final lowerQuery = query.toLowerCase();
    final lowerContent = _getLowerContent();
    final matchIds = state.messages
        .where((m) => (lowerContent[m.id] ?? '').contains(lowerQuery))
        .map((m) => m.id)
        .toList(growable: false);
    state = state.copyWith(
      searchQuery: query,
      searchMatchIds: matchIds,
      currentSearchMatchIndex: matchIds.isEmpty ? -1 : 0,
    );
  }

  void nextSearchResult() {
    if (state.searchMatchIds.isEmpty) return;
    final next =
        (state.currentSearchMatchIndex + 1) % state.searchMatchIds.length;
    state = state.copyWith(currentSearchMatchIndex: next);
  }

  void previousSearchResult() {
    if (state.searchMatchIds.isEmpty) return;
    final prev =
        (state.currentSearchMatchIndex - 1 + state.searchMatchIds.length) %
            state.searchMatchIds.length;
    state = state.copyWith(currentSearchMatchIndex: prev);
  }
}
