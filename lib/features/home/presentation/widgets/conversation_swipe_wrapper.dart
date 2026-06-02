import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/widgets/swipe_action_wrapper.dart';
import 'package:slock_app/core/haptic/haptic_service.dart';
import 'package:slock_app/features/home/application/conversation_swipe_preference.dart';
import 'package:slock_app/l10n/l10n.dart';

class ConversationSwipeActions {
  const ConversationSwipeActions({
    required this.left,
    required this.right,
  });

  final ConversationSwipeAction left;
  final ConversationSwipeAction right;
}

class ConversationSwipeCallbacks {
  const ConversationSwipeCallbacks({
    this.onArchive,
    this.onTogglePin,
    this.onToggleMute,
  });

  final VoidCallback? onArchive;
  final VoidCallback? onTogglePin;
  final VoidCallback? onToggleMute;

  VoidCallback? callbackFor(ConversationSwipeAction action) {
    return switch (action) {
      ConversationSwipeAction.none => null,
      ConversationSwipeAction.archive => onArchive,
      ConversationSwipeAction.togglePin => onTogglePin,
      ConversationSwipeAction.toggleMute => onToggleMute,
    };
  }
}

class ConversationSwipeWrapper extends ConsumerWidget {
  const ConversationSwipeWrapper({
    super.key,
    required this.itemKey,
    required this.actions,
    required this.callbacks,
    required this.isPinned,
    required this.isMuted,
    required this.child,
  });

  final String itemKey;
  final ConversationSwipeActions actions;
  final ConversationSwipeCallbacks callbacks;
  final bool isPinned;
  final bool isMuted;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leftAction = callbacks.callbackFor(actions.left) == null
        ? ConversationSwipeAction.none
        : actions.left;
    final rightAction = callbacks.callbackFor(actions.right) == null
        ? ConversationSwipeAction.none
        : actions.right;

    return SwipeActionWrapper(
      itemKey: 'conversation-$itemKey',
      enabled: leftAction != ConversationSwipeAction.none ||
          rightAction != ConversationSwipeAction.none,
      startToEndAction: _configFor(context, rightAction),
      endToStartAction: _configFor(context, leftAction),
      onStartToEndAction: callbacks.callbackFor(rightAction),
      onEndToStartAction: callbacks.callbackFor(leftAction),
      onThresholdHaptic: () =>
          ref.read(hapticServiceProvider).mediumImpact(),
      child: child,
    );
  }

  SwipeActionConfig? _configFor(
    BuildContext context,
    ConversationSwipeAction action,
  ) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    return switch (action) {
      ConversationSwipeAction.none => null,
      ConversationSwipeAction.archive => SwipeActionConfig(
          label: l10n.conversationSwipeArchive,
          icon: Icons.archive_outlined,
          color: colors.warning,
        ),
      ConversationSwipeAction.togglePin => SwipeActionConfig(
          label: isPinned
              ? l10n.conversationSwipeUnpin
              : l10n.conversationSwipePin,
          icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
          color: colors.primary,
        ),
      ConversationSwipeAction.toggleMute => SwipeActionConfig(
          label: isMuted
              ? l10n.conversationSwipeUnmute
              : l10n.conversationSwipeMute,
          icon: isMuted
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          color: colors.textSecondary,
        ),
    };
  }
}
