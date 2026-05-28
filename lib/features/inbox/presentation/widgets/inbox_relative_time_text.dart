import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/l10n/l10n.dart';

/// A leaf [ConsumerWidget] that watches [homeNowProvider] internally and
/// renders a compact relative time string using inbox-specific l10n keys.
///
/// By isolating the provider watch into this tiny widget, the parent
/// [InboxItemTile] avoids rebuilding every 60 seconds. Only this leaf
/// rebuilds when the minute tick fires.
///
/// Format: "now" / "5m" / "2h" / "3d" / "May 27" (locale-aware).
class InboxRelativeTimeText extends ConsumerWidget {
  const InboxRelativeTimeText({
    super.key,
    required this.time,
    required this.style,
  });

  /// The timestamp to format relative to the current time.
  final DateTime time;

  /// Text style for the rendered time label.
  final TextStyle? style;

  /// Cached [DateFormat] instances keyed by locale name. Avoids allocating a
  /// new formatter on every rebuild — a significant cost when scrolling
  /// through hundreds of inbox items.
  static final Map<String, DateFormat> _dateFormatCache = {};

  /// Number of entries in the DateFormat cache. Exposed for testing.
  @visibleForTesting
  static int get dateFormatCacheSize => _dateFormatCache.length;

  /// Clears the DateFormat cache. Exposed for testing.
  @visibleForTesting
  static void clearDateFormatCache() => _dateFormatCache.clear();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(homeNowProvider).value ?? DateTime.now();
    final l10n = context.l10n;
    return Text(
      _formatTime(time, now, l10n),
      style: style,
    );
  }

  static String _formatTime(
    DateTime time,
    DateTime now,
    AppLocalizations l10n,
  ) {
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return l10n.inboxTimeNow;
    if (diff.inMinutes < 60) return l10n.inboxTimeMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.inboxTimeHours(diff.inHours);
    if (diff.inDays < 7) return l10n.inboxTimeDays(diff.inDays);
    final locale = l10n.localeName;
    final formatter = _dateFormatCache[locale] ??= DateFormat.MMMd(locale);
    return formatter.format(time);
  }
}
