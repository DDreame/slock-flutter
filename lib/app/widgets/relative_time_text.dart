import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/utils/time_format.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/l10n/l10n.dart';

/// A leaf ConsumerWidget that watches [homeNowProvider] internally and renders
/// a relative time string via [formatRelativeTime].
///
/// By isolating the provider watch into this tiny widget, parent rows (channel,
/// DM, task, search result) avoid rebuilding every 60 seconds. Only this leaf
/// rebuilds when the minute tick fires.
///
/// Usage:
/// ```dart
/// RelativeTimeText(
///   time: channel.lastActivityAt!,
///   style: AppTypography.caption.copyWith(color: colors.textTertiary),
/// )
/// ```
class RelativeTimeText extends ConsumerWidget {
  const RelativeTimeText({
    super.key,
    required this.time,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  /// The timestamp to format relative to the current time.
  final DateTime time;

  /// Text style for the rendered time label.
  final TextStyle? style;

  /// Optional max lines constraint.
  final int? maxLines;

  /// Optional overflow behavior.
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(homeNowProvider).value ?? DateTime.now();
    return Text(
      formatRelativeTime(time, now: now, l10n: context.l10n),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
