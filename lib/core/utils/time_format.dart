import 'package:intl/intl.dart';
import 'package:slock_app/l10n/app_localizations.dart';

/// Formats [dt] relative to [now] using localized strings when [l10n] is
/// provided. Falls back to hardcoded English when [l10n] is null (legacy
/// compatibility).
///
/// When [l10n] is provided, weekday and month names use ICU DateFormat
/// with the locale from [l10n.localeName], producing localized output
/// (e.g. ZH: "周一 14:30", "5月 27, 14:30").
String formatRelativeTime(
  DateTime dt, {
  DateTime? now,
  AppLocalizations? l10n,
}) {
  final local = dt.toLocal();
  final currentTime = now ?? DateTime.now();
  final diff = currentTime.difference(local);

  if (diff.inMinutes < 1) {
    return l10n?.timeJustNow ?? 'just now';
  }
  if (diff.inMinutes < 60) {
    return l10n?.timeMinutesAgo(diff.inMinutes) ?? '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return l10n?.timeHoursAgo(diff.inHours) ?? '${diff.inHours}h ago';
  }

  final localTime = _formatTime(local);

  if (diff.inDays < 7) {
    if (l10n != null) {
      final weekday = DateFormat.E(l10n.localeName).format(local);
      return '$weekday $localTime';
    }
    return '${_weekday(local.weekday)} $localTime';
  }

  if (l10n != null) {
    final monthDay = DateFormat.MMMd(l10n.localeName).format(local);
    return '$monthDay, $localTime';
  }
  return '${_month(local.month)} ${local.day}, $localTime';
}

String formatTimeOnly(DateTime dt) {
  return _formatTime(dt.toLocal());
}

String _formatTime(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

String _weekday(int weekday) {
  return switch (weekday) {
    1 => 'Mon',
    2 => 'Tue',
    3 => 'Wed',
    4 => 'Thu',
    5 => 'Fri',
    6 => 'Sat',
    7 => 'Sun',
    _ => '',
  };
}

String _month(int month) {
  return switch (month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    12 => 'Dec',
    _ => '',
  };
}
