import 'package:flutter/material.dart';
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
/// - Haptic feedback: fires [onThresholdHaptic] when the user drags
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
    this.onThresholdHaptic,
  });

  /// Unique key for the Dismissible (typically a scope id or item id).
  final String itemKey;

  /// Whether the swipe gesture is active.
  final bool enabled;

  /// Visual configuration for the swipe background.
  final SwipeActionConfig action;

  /// Called when the user completes the left-swipe gesture.
  final VoidCallback onAction;

  /// Optional haptic callback fired when swipe crosses threshold.
  final Future<void> Function()? onThresholdHaptic;

  /// The row widget to wrap.
  final Widget child;

  @override
  State<SwipeActionWrapper> createState() => _SwipeActionWrapperState();
}

class _SwipeActionWrapperState extends State<SwipeActionWrapper> {
  // Hoisted BorderRadius for swipe background (Scan #45).
  static final _kBorderRadius = BorderRadius.circular(AppSpacing.radiusMd);

  bool _hapticFired = false;
  double? _dragStartX;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final action = widget.action;

    return Listener(
      // Track horizontal drag distance for haptic feedback.
      // We use Listener to avoid competing with Dismissible's gesture arena.
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (_) => _resetDrag(),
      onPointerCancel: (_) => _resetDrag(),
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
            borderRadius: _kBorderRadius,
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

  void _onPointerDown(PointerDownEvent event) {
    _dragStartX = event.position.dx;
    _hapticFired = false;
  }

  void _resetDrag() {
    _dragStartX = null;
    _hapticFired = false;
  }

  /// Fires haptic feedback once when the leftward drag distance exceeds 15%
  /// of the widget width.
  ///
  /// Uses the delta from the initial touch point (not the pointer's absolute
  /// position) so the threshold is consistent regardless of where the finger
  /// starts.
  void _onPointerMove(PointerMoveEvent event) {
    if (_hapticFired || !widget.enabled || _dragStartX == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final width = renderBox.size.width;
    // Positive dragDelta = finger moved left (end-to-start).
    final dragDelta = _dragStartX! - event.position.dx;

    if (dragDelta > width * 0.15) {
      _hapticFired = true;
      widget.onThresholdHaptic?.call();
    }
  }
}
