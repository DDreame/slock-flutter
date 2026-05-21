import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/features/search/application/search_history_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

/// #676: Full test coverage for SearchHistoryNotifier.
///
/// Covers: addQuery persistence, LRU dedup, max entries eviction,
/// clearHistory, empty-state, and SharedPreferences integration.
void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SearchHistoryNotifier', () {
    test('initial state is empty when no persisted data', () {
      final state = container.read(searchHistoryProvider);
      expect(state, isEmpty);
    });

    test('addQuery persists query and appears in state', () {
      container.read(searchHistoryProvider.notifier).addQuery('hello');
      final state = container.read(searchHistoryProvider);
      expect(state, ['hello']);
      // Verify SharedPreferences persistence.
      expect(prefs.getStringList('search_history'), ['hello']);
    });

    test('addQuery trims whitespace', () {
      container.read(searchHistoryProvider.notifier).addQuery('  spaces  ');
      final state = container.read(searchHistoryProvider);
      expect(state, ['spaces']);
    });

    test('addQuery ignores empty/whitespace-only input', () {
      container.read(searchHistoryProvider.notifier).addQuery('');
      container.read(searchHistoryProvider.notifier).addQuery('   ');
      final state = container.read(searchHistoryProvider);
      expect(state, isEmpty);
    });

    test('addQuery moves duplicate to front (LRU)', () {
      final notifier = container.read(searchHistoryProvider.notifier);
      notifier.addQuery('alpha');
      notifier.addQuery('beta');
      notifier.addQuery('gamma');

      expect(container.read(searchHistoryProvider), ['gamma', 'beta', 'alpha']);

      // Re-add 'alpha' — should move to front.
      notifier.addQuery('alpha');
      expect(container.read(searchHistoryProvider), ['alpha', 'gamma', 'beta']);
    });

    test('addQuery evicts oldest when exceeding max entries', () {
      final notifier = container.read(searchHistoryProvider.notifier);
      // Fill to max (10 entries).
      for (var i = 0; i < searchHistoryMaxEntries; i++) {
        notifier.addQuery('query-$i');
      }
      expect(
        container.read(searchHistoryProvider).length,
        searchHistoryMaxEntries,
      );

      // Add one more — oldest (query-0) should be evicted.
      notifier.addQuery('overflow');
      final state = container.read(searchHistoryProvider);
      expect(state.length, searchHistoryMaxEntries);
      expect(state.first, 'overflow');
      expect(state.contains('query-0'), isFalse);
      // query-1 should still be present (it was index 1, now pushed to end-1).
      expect(state.contains('query-1'), isTrue);
    });

    test('clearHistory removes all entries from state and prefs', () {
      final notifier = container.read(searchHistoryProvider.notifier);
      notifier.addQuery('one');
      notifier.addQuery('two');
      expect(container.read(searchHistoryProvider), isNotEmpty);

      notifier.clearHistory();
      expect(container.read(searchHistoryProvider), isEmpty);
      expect(prefs.getStringList('search_history'), isNull);
    });

    test('loads persisted entries on build', () async {
      // Pre-populate SharedPreferences.
      await prefs.setStringList('search_history', ['saved-1', 'saved-2']);

      // Create a fresh container to trigger build().
      final freshContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(freshContainer.dispose);

      final state = freshContainer.read(searchHistoryProvider);
      expect(state, ['saved-1', 'saved-2']);
    });
  });
}
