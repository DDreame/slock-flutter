import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Maximum number of recent search queries to retain (LRU).
const int searchHistoryMaxEntries = 10;

/// State type for search history — an ordered list of recent queries.
typedef SearchHistoryState = List<String>;

/// Provider for the search history notifier.
final searchHistoryProvider =
    NotifierProvider.autoDispose<SearchHistoryNotifier, SearchHistoryState>(
  SearchHistoryNotifier.new,
);

/// Manages a persisted list of recent search queries.
///
/// Phase A: stub — throws [UnimplementedError].
/// Phase B: real implementation backed by SharedPreferences.
class SearchHistoryNotifier extends AutoDisposeNotifier<SearchHistoryState> {
  @override
  SearchHistoryState build() {
    throw UnimplementedError(
      'SearchHistoryNotifier.build not yet implemented',
    );
  }

  /// Add a query to the history (most recent first, LRU eviction).
  ///
  /// If the query already exists, it is moved to the front.
  /// If the history exceeds [searchHistoryMaxEntries], the oldest is removed.
  void addQuery(String query) {
    throw UnimplementedError(
      'SearchHistoryNotifier.addQuery not yet implemented',
    );
  }

  /// Clear all history entries.
  void clearHistory() {
    throw UnimplementedError(
      'SearchHistoryNotifier.clearHistory not yet implemented',
    );
  }
}
