import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/utils/time_format.dart';

void main() {
  group('formatRelativeTime', () {
    test('returns "just now" for less than 1 minute ago', () {
      final now = DateTime.now();
      final dt = now.subtract(const Duration(seconds: 30));
      expect(formatRelativeTime(dt), 'just now');
    });

    test('returns minutes ago for less than 1 hour', () {
      final now = DateTime.now();
      final dt = now.subtract(const Duration(minutes: 5));
      expect(formatRelativeTime(dt), '5m ago');
    });

    test('returns hours ago for less than 24 hours', () {
      final now = DateTime.now();
      final dt = now.subtract(const Duration(hours: 3));
      expect(formatRelativeTime(dt), '3h ago');
    });

    test('returns weekday and time for less than 7 days', () {
      final now = DateTime.now();
      final dt = now.subtract(const Duration(days: 2));
      final local = dt.toLocal();
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final expected = '${weekdays[local.weekday - 1]} $hour:$minute';
      expect(formatRelativeTime(dt), expected);
    });

    test('returns month day and time for 7+ days ago', () {
      final now = DateTime.now();
      final dt = now.subtract(const Duration(days: 10));
      final local = dt.toLocal();
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final expected = '${months[local.month - 1]} ${local.day}, $hour:$minute';
      expect(formatRelativeTime(dt), expected);
    });

    test('converts UTC datetime to local before formatting', () {
      final now = DateTime.now();
      final utcDt = now.subtract(const Duration(minutes: 15)).toUtc();
      expect(formatRelativeTime(utcDt), '15m ago');
    });
  });

  group('formatTimeOnly', () {
    test('returns HH:mm in local time', () {
      final dt = DateTime.utc(2026, 4, 29, 14, 5);
      final local = dt.toLocal();
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      expect(formatTimeOnly(dt), '$hour:$minute');
    });
  });
}
