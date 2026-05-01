import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';

/// Primary-colored count pill for unread channel/DM indicators.
///
/// Hides entirely when [count] is 0. Displays "99+" for counts above 99.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({
    super.key,
    required this.count,
  });

  /// The unread message count.
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).extension<AppColors>()!;
    final displayText = count > 99 ? '99+' : '$count';

    return Container(
      key: const ValueKey('unread-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        displayText,
        style: AppTypography.caption.copyWith(
          color: colors.primaryForeground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
