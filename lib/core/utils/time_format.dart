import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:slock_app/l10n/app_localizations.dart';

/// Static cache for [DateFormat.E] instances keyed by locale.
/// Avoids ~40 allocations/minute from repeated `DateFormat.E(locale)` calls
/// in timestamp rendering. INV-842-CACHE.
final Map<String, DateFormat> _weekdayFormatCache = {};

/// Static cache for [DateFormat.MMMd] instances keyed by locale.
final Map<String, DateFormat> _monthDayFormatCache = {};

DateFormat _cachedWeekdayFormat(String locale) {
  return _weekdayFormatCache[locale] ??= DateFormat.E(locale);
}

DateFormat _cachedMonthDayFormat(String locale) {
  return _monthDayFormatCache[locale] ??= DateFormat.MMMd(locale);
}

/// INV-842-CACHE: @visibleForTesting — current size of the weekday cache.
/// Used by tests to prove caching is load-bearing (removing cache → size grows
/// unbounded on repeated calls with same locale).
@visibleForTesting
int get weekdayFormatCacheSize => _weekdayFormatCache.length;

/// INV-842-CACHE: @visibleForTesting — current size of the month+day cache.
@visibleForTesting
int get monthDayFormatCacheSize => _monthDayFormatCache.length;

/// INV-842-CACHE: @visibleForTesting — reset caches between tests.
@visibleForTesting
void resetDateFormatCaches() {
  _weekdayFormatCache.clear();
  _monthDayFormatCache.clear();
}

/// Formats [dt] relative to [now] using localized strings from [l10n].
///
/// When [l10n] is provided, weekday and month names use ICU DateFormat
/// with the locale from [l10n.localeName], producing localized output
/// (e.g. ZH: "周一 14:30", "5月 27, 14:30").
String formatRelativeTime(
  DateTime dt, {
  DateTime? now,
  required AppLocalizations l10n,
}) {
  final local = dt.toLocal();
  final currentTime = now ?? DateTime.now();
  final diff = currentTime.difference(local);

  if (diff.inMinutes < 1) {
    return l10n.timeJustNow;
  }
  if (diff.inMinutes < 60) {
    return l10n.timeMinutesAgo(diff.inMinutes);
  }
  if (diff.inHours < 24) {
    return l10n.timeHoursAgo(diff.inHours);
  }

  final localTime = _formatTime(local);

  if (diff.inDays < 7) {
    final weekday = _cachedWeekdayFormat(l10n.localeName).format(local);
    return '$weekday $localTime';
  }

  final monthDay = _cachedMonthDayFormat(l10n.localeName).format(local);
  return '$monthDay, $localTime';
}

String _formatTime(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
