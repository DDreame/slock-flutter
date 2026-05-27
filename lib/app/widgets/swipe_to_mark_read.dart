import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/widgets/swipe_action_wrapper.dart';
import 'package:slock_app/l10n/l10n.dart';

/// A convenience wrapper that provides a left-swipe "Mark Read" gesture.
///
/// Delegates to [SwipeActionWrapper] with a pre-configured [SwipeActionConfig]
/// for the "Mark Read" action. The item stays in the list after the swipe.
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
    final colors = Theme.of(context).extension<AppColors>()!;

    return SwipeActionWrapper(
      itemKey: itemKey,
      enabled: enabled,
      action: SwipeActionConfig(
        label: context.l10n.inboxActionMarkRead,
        icon: Icons.mark_email_read,
        color: colors.primary,
      ),
      onAction: onMarkRead,
      child: child,
    );
  }
}
