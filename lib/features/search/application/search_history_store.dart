import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

/// Maximum number of recent search queries to retain (LRU).
const int searchHistoryMaxEntries = 10;

/// SharedPreferences key used to persist the search history list.
const String _prefsKey = 'search_history';

/// State type for search history — an ordered list of recent queries.
typedef SearchHistoryState = List<String>;

/// Provider for the search history notifier.
final searchHistoryProvider =
    NotifierProvider.autoDispose<SearchHistoryNotifier, SearchHistoryState>(
  SearchHistoryNotifier.new,
);

/// Manages a persisted list of recent search queries.
///
/// Backed by [SharedPreferences]. Queries are stored most-recent-first
/// with LRU eviction at [searchHistoryMaxEntries].
class SearchHistoryNotifier extends AutoDisposeNotifier<SearchHistoryState> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  SearchHistoryState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getStringList(_prefsKey);
    return stored ?? <String>[];
  }

  /// Add a query to the history (most recent first, LRU eviction).
  ///
  /// If the query already exists, it is moved to the front.
  /// If the history exceeds [searchHistoryMaxEntries], the oldest is removed.
  void addQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final current = List<String>.of(state);
    // Remove existing duplicate (LRU: move to front).
    current.remove(trimmed);
    // Insert at front (most recent first).
    current.insert(0, trimmed);
    // Evict oldest if over capacity.
    if (current.length > searchHistoryMaxEntries) {
      current.removeRange(searchHistoryMaxEntries, current.length);
    }
    state = current;
    _persist(current);
  }

  /// Clear all history entries.
  void clearHistory() {
    state = <String>[];
    _prefs.remove(_prefsKey);
  }

  void _persist(List<String> entries) {
    _prefs.setStringList(_prefsKey, entries);
  }
}
