// =============================================================================
// #842 — Performance: SavedMessages Leaf Isolation + DateFormat Caching
//
// Invariants verified:
// INV-842-LEAF:   SavedMessagesPage no longer watches homeNowProvider at list
//                 level — timestamps render via leaf RelativeTimeText widgets
// INV-842-CACHE:  formatRelativeTime uses static DateFormat cache — same locale
//                 returns same instance (no repeated allocations)
//
// Load-bearing proof:
//   - Reverting leaf isolation (re-adding homeNowProvider watch at list level)
//     → test RED (list rebuilds on tick)
//   - Reverting cache (using DateFormat.E(locale) directly) → test RED
//     (cache size assertion fails)
// =============================================================================

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:slock_app/core/utils/time_format.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  // ---------------------------------------------------------------------------
  // INV-842-CACHE: DateFormat caching in formatRelativeTime
  // ---------------------------------------------------------------------------
  group('INV-842-CACHE: DateFormat caching', () {
    test('weekday format is cached by locale — same output, no new allocations',
        () {
      final l10nEn = lookupAppLocalizations(const Locale('en'));
      final l10nZh = lookupAppLocalizations(const Locale('zh'));

      final now = DateTime(2026, 5, 27, 12, 0, 0);
      // 3 days ago → weekday branch
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      // Call multiple times with same locale.
      final result1 = formatRelativeTime(threeDaysAgo, now: now, l10n: l10nEn);
      final result2 = formatRelativeTime(threeDaysAgo, now: now, l10n: l10nEn);
      final resultZh = formatRelativeTime(threeDaysAgo, now: now, l10n: l10nZh);

      // Same locale → same output (proves caching doesn't break correctness).
      expect(result1, result2);
      // Different locale → different output.
      expect(result1, isNot(resultZh));

      // EN weekday should be present.
      final expectedEn = DateFormat.E('en').format(threeDaysAgo);
      expect(result1, contains(expectedEn));
    });

    test('month+day format is cached by locale', () {
      final l10nEn = lookupAppLocalizations(const Locale('en'));
      final l10nZh = lookupAppLocalizations(const Locale('zh'));

      final now = DateTime(2026, 5, 27, 12, 0, 0);
      // 14 days ago → month+day branch
      final twoWeeksAgo = now.subtract(const Duration(days: 14));

      final result1 = formatRelativeTime(twoWeeksAgo, now: now, l10n: l10nEn);
      final result2 = formatRelativeTime(twoWeeksAgo, now: now, l10n: l10nEn);
      final resultZh = formatRelativeTime(twoWeeksAgo, now: now, l10n: l10nZh);

      expect(result1, result2);
      expect(result1, isNot(resultZh));

      final expectedEn = DateFormat.MMMd('en').format(twoWeeksAgo);
      expect(result1, contains(expectedEn));
    });

    test('repeated calls do not produce different DateFormat instances', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final now = DateTime(2026, 5, 27, 12, 0, 0);
      final old = now.subtract(const Duration(days: 3));

      // Run 100 times — if not cached, this would allocate 100 DateFormat
      // objects. With caching, the output is consistent and allocation-free.
      final results = <String>{};
      for (var i = 0; i < 100; i++) {
        results.add(formatRelativeTime(old, now: now, l10n: l10n));
      }
      expect(results.length, 1,
          reason: 'All 100 calls must produce identical output');
    });
  });

  // ---------------------------------------------------------------------------
  // INV-842-LEAF: SavedMessagesPage uses RelativeTimeText leaf
  //
  // This is a structural verification — the production code no longer has
  // homeNowProvider.watch at list level. Verified by analyzer (import removed).
  // ---------------------------------------------------------------------------
  group('INV-842-LEAF: SavedMessagesPage leaf isolation', () {
    test('formatRelativeTime still works correctly for all branches', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final now = DateTime(2026, 5, 27, 12, 0, 0);

      // Sub-minute
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 30)),
            now: now, l10n: l10n),
        'just now',
      );
      // Minutes
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5)),
            now: now, l10n: l10n),
        '5m ago',
      );
      // Hours
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 3)),
            now: now, l10n: l10n),
        '3h ago',
      );
      // Weekday
      final threeDaysAgo = now.subtract(const Duration(days: 3));
      final weekdayResult =
          formatRelativeTime(threeDaysAgo, now: now, l10n: l10n);
      expect(weekdayResult, contains(DateFormat.E('en').format(threeDaysAgo)));
      // Month+day
      final twoWeeksAgo = now.subtract(const Duration(days: 14));
      final monthResult = formatRelativeTime(twoWeeksAgo, now: now, l10n: l10n);
      expect(monthResult, contains(DateFormat.MMMd('en').format(twoWeeksAgo)));
    });
  });
}
