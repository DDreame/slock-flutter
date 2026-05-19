// ignore_for_file: unused_local_variable
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/search/application/search_history_store.dart';

void main() {
  group('Search recent queries', () {
    test(
      'T1: Submitted query is saved to history',
      skip: true,
      () {
        // Arrange
        final container = ProviderContainer();
        final sub = container.listen(searchHistoryProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        final notifier = container.read(searchHistoryProvider.notifier);

        // Act
        notifier.addQuery('hello world');

        // Assert
        final history = container.read(searchHistoryProvider);
        expect(history, contains('hello world'));
      },
    );

    test(
      'T2: Recent queries displayed as chips below search field',
      skip: true,
      () {
        // Arrange — seed history with 3 queries.
        final container = ProviderContainer();
        final sub = container.listen(searchHistoryProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        final notifier = container.read(searchHistoryProvider.notifier);
        notifier.addQuery('query-1');
        notifier.addQuery('query-2');
        notifier.addQuery('query-3');

        // Assert — 3 entries in history (most recent first).
        final history = container.read(searchHistoryProvider);
        expect(history.length, equals(3));
        expect(history.first, equals('query-3'));
      },
    );

    test(
      'T3: Tapping a chip fills the search field (query re-added to top)',
      skip: true,
      () {
        // Arrange — seed history.
        final container = ProviderContainer();
        final sub = container.listen(searchHistoryProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        final notifier = container.read(searchHistoryProvider.notifier);
        notifier.addQuery('first');
        notifier.addQuery('second');
        notifier.addQuery('third');

        // Act — re-add 'first' (simulates tap on chip).
        notifier.addQuery('first');

        // Assert — 'first' is now at the top, no duplicates.
        final history = container.read(searchHistoryProvider);
        expect(history.first, equals('first'));
        expect(history.where((q) => q == 'first').length, equals(1));
      },
    );

    test(
      'T4: History limited to max N entries (LRU)',
      skip: true,
      () {
        // Arrange
        final container = ProviderContainer();
        final sub = container.listen(searchHistoryProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        final notifier = container.read(searchHistoryProvider.notifier);

        // Act — add more than max entries.
        for (var i = 0; i < searchHistoryMaxEntries + 3; i++) {
          notifier.addQuery('query-$i');
        }

        // Assert — history is capped at max.
        final history = container.read(searchHistoryProvider);
        expect(history.length, equals(searchHistoryMaxEntries));
        // Oldest entries evicted (query-0, query-1, query-2 gone).
        expect(history, isNot(contains('query-0')));
        expect(history, isNot(contains('query-1')));
        expect(history, isNot(contains('query-2')));
        // Most recent is at front.
        expect(
          history.first,
          equals('query-${searchHistoryMaxEntries + 2}'),
        );
      },
    );

    test(
      'T5: Clear history action removes all entries',
      skip: true,
      () {
        // Arrange
        final container = ProviderContainer();
        final sub = container.listen(searchHistoryProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        final notifier = container.read(searchHistoryProvider.notifier);
        notifier.addQuery('query-1');
        notifier.addQuery('query-2');

        // Act
        notifier.clearHistory();

        // Assert
        final history = container.read(searchHistoryProvider);
        expect(history, isEmpty);
      },
    );
  });
}
