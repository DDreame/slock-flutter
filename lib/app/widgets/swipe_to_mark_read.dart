import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';

/// A wrapper that adds a left-swipe (end-to-start) "Mark Read" gesture to its
/// child widget.
///
/// Consistent with the Inbox swipe pattern: the item remains in the list after
/// the swipe action (confirmDismiss returns false), and the swipe reveals a
/// tinted background with a checkmark icon and "Mark Read" label.
///
/// Only active when [enabled] is true (i.e. the item actually has unread
/// messages). When disabled, the child is rendered without any Dismissible
/// wrapper to avoid unnecessary gesture interference.
class SwipeToMarkRead extends StatelessWidget {
  const SwipeToMarkRead({
    super.key,
    required this.itemKey,
    required this.enabled,
    required this.onMarkRead,
    required this.child,
  });

  /// Unique key for the Dismissible (typically the channel/DM scope id).
  final String itemKey;

  /// Whether the swipe gesture is active. When false, the child is rendered
  /// without the Dismissible wrapper.
  final bool enabled;

  /// Called when the user completes the left-swipe gesture.
  final VoidCallback onMarkRead;

  /// The row widget to wrap.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final colors = Theme.of(context).extension<AppColors>()!;

    return Dismissible(
      key: ValueKey('swipe-mark-read-$itemKey'),
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        key: const ValueKey('swipe-mark-read-background'),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mark_email_read, color: colors.primary, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Mark Read',
              style: AppTypography.label.copyWith(color: colors.primary),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        onMarkRead();
        // Always return false: the item stays in the list.
        return false;
      },
      child: child,
    );
  }
}
