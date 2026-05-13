import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';

/// Configuration for the swipe action background.
class SwipeActionConfig {
  const SwipeActionConfig({
    required this.label,
    required this.icon,
    required this.color,
    this.dismisses = false,
  });

  /// Label shown alongside the icon during the swipe.
  final String label;

  /// Icon displayed in the swipe background.
  final IconData icon;

  /// Accent color for icon, label, and tinted background.
  final Color color;

  /// If true, the item is removed from the list after the swipe completes.
  /// If false, the item stays in place (e.g. "Mark Read").
  final bool dismisses;
}

/// A configurable wrapper that adds a left-swipe (end-to-start) action
/// with haptic feedback at threshold crossing.
///
/// Unified swipe pattern for all list pages:
/// - Left-swipe: configurable primary action (mark read, mark done, etc.)
/// - Haptic feedback: fires [HapticFeedback.mediumImpact] when the user drags
///   past the dismiss threshold (consistent with [MessageGestureWrapper]).
/// - Guard: when [enabled] is false, the child is rendered without any
///   [Dismissible] wrapper to avoid gesture interference.
///
/// Replaces the simpler [SwipeToMarkRead] with a more flexible API.
class SwipeActionWrapper extends StatefulWidget {
  const SwipeActionWrapper({
    super.key,
    required this.itemKey,
    required this.enabled,
    required this.action,
    required this.onAction,
    required this.child,
  });

  /// Unique key for the Dismissible (typically a scope id or item id).
  final String itemKey;

  /// Whether the swipe gesture is active.
  final bool enabled;

  /// Visual configuration for the swipe background.
  final SwipeActionConfig action;

  /// Called when the user completes the left-swipe gesture.
  final VoidCallback onAction;

  /// The row widget to wrap.
  final Widget child;

  @override
  State<SwipeActionWrapper> createState() => _SwipeActionWrapperState();
}

class _SwipeActionWrapperState extends State<SwipeActionWrapper> {
  bool _hapticFired = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final action = widget.action;

    return Listener(
      // Track horizontal drag distance for haptic feedback.
      // We use Listener to avoid competing with Dismissible's gesture arena.
      onPointerMove: _onPointerMove,
      onPointerUp: (_) => _hapticFired = false,
      onPointerCancel: (_) => _hapticFired = false,
      child: Dismissible(
        key: ValueKey('swipe-action-${widget.itemKey}'),
        direction: DismissDirection.endToStart,
        background: const SizedBox.shrink(),
        secondaryBackground: Container(
          key: const ValueKey('swipe-action-background'),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          decoration: BoxDecoration(
            color: action.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, color: action.color, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(
                action.label,
                style: AppTypography.label.copyWith(color: action.color),
              ),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          widget.onAction();
          return action.dismisses;
        },
        child: widget.child,
      ),
    );
  }

  /// Fires haptic feedback once when the swipe crosses the threshold.
  /// The default Dismissible threshold is 0.4 of the widget width.
  /// We fire haptic at ~0.15 (early threshold) for tactile confirmation,
  /// matching the MessageGestureWrapper's 60px pattern.
  void _onPointerMove(PointerMoveEvent event) {
    if (_hapticFired || !widget.enabled) return;
    // Negative delta.dx indicates a left-swipe (end-to-start).
    // We track cumulative offset via the Dismissible's own gesture,
    // but for haptic purposes we can use a simple position heuristic:
    // if the pointer has moved more than 60px to the left, fire haptic.
    // This is approximate but effective since the Listener sees raw events.
    if (event.delta.dx < -2) {
      // Check if we've moved far enough for haptic feedback.
      // We use the localPosition approach: if the pointer is significantly
      // left of center, the user has swiped past the feedback threshold.
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final width = renderBox.size.width;
        final localX = renderBox.globalToLocal(event.position).dx;
        // Fire haptic when the swipe reveals ~15% of the background.
        if (localX < width * 0.85) {
          _hapticFired = true;
          HapticFeedback.mediumImpact();
        }
      }
    }
  }
}
