import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/utils/time_format.dart';

/// #812: Verify `formatRelativeTime` respects the `now` parameter
/// and does not use an internal `DateTime.now()` when `now:` is passed.
void main() {
  group('formatRelativeTime uses explicit now param', () {
    test('returns "just now" when diff < 1 minute', () {
      final dt = DateTime(2026, 5, 20, 10, 0, 0);
      final now = DateTime(2026, 5, 20, 10, 0, 30);
      expect(formatRelativeTime(dt, now: now), 'just now');
    });

    test('returns minutes ago when diff < 60 minutes', () {
      final dt = DateTime(2026, 5, 20, 10, 0, 0);
      final now = DateTime(2026, 5, 20, 10, 25, 0);
      expect(formatRelativeTime(dt, now: now), '25m ago');
    });

    test('returns hours ago when diff < 24 hours', () {
      final dt = DateTime(2026, 5, 20, 10, 0, 0);
      final now = DateTime(2026, 5, 20, 14, 0, 0);
      expect(formatRelativeTime(dt, now: now), '4h ago');
    });

    test('returns weekday when diff < 7 days', () {
      // May 20, 2026 is a Wednesday
      final dt = DateTime(2026, 5, 20, 10, 0, 0);
      final now = DateTime(2026, 5, 22, 10, 0, 0); // 2 days later
      expect(formatRelativeTime(dt, now: now), 'Wed 10:00');
    });

    test('returns month day when diff >= 7 days', () {
      final dt = DateTime(2026, 5, 10, 14, 30, 0);
      final now = DateTime(2026, 5, 25, 10, 0, 0); // 15 days later
      expect(formatRelativeTime(dt, now: now), 'May 10, 14:30');
    });

    test('result is deterministic for same now — no internal DateTime.now()',
        () {
      final dt = DateTime(2026, 1, 15, 8, 0, 0);
      final fixedNow = DateTime(2026, 1, 15, 11, 30, 0);

      // Call multiple times — same result proves no internal DateTime.now()
      final result1 = formatRelativeTime(dt, now: fixedNow);
      final result2 = formatRelativeTime(dt, now: fixedNow);
      final result3 = formatRelativeTime(dt, now: fixedNow);

      expect(result1, '3h ago');
      expect(result2, result1);
      expect(result3, result1);
    });
  });
}
