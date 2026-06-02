import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';

/// Configuration for a swipe action background.
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
  /// If false, the item stays in place.
  final bool dismisses;
}

/// A configurable wrapper that adds one or two horizontal swipe actions.
///
/// Unified swipe pattern for all list pages:
/// - Left-swipe: configurable primary action (mark read, mark done, etc.)
/// - Haptic feedback: fires [onThresholdHaptic] when the user drags
///   past the dismiss threshold (consistent with [MessageGestureWrapper]).
/// - Guard: when [enabled] is false, the child is rendered without any
///   [Dismissible] wrapper to avoid gesture interference.
///
/// The legacy [action]/[onAction] constructor fields configure the left swipe
/// (end-to-start) path used by existing mark-read rows. New callers can provide
/// [startToEndAction] and [endToStartAction] for right/left conversation swipes.
class SwipeActionWrapper extends StatefulWidget {
  const SwipeActionWrapper({
    super.key,
    required this.itemKey,
    required this.enabled,
    SwipeActionConfig? action,
    VoidCallback? onAction,
    this.startToEndAction,
    SwipeActionConfig? endToStartAction,
    this.onStartToEndAction,
    VoidCallback? onEndToStartAction,
    required this.child,
    this.onThresholdHaptic,
  })  : endToStartAction = endToStartAction ?? action,
        onEndToStartAction = onEndToStartAction ?? onAction;

  /// Unique key for the Dismissible (typically a scope id or item id).
  final String itemKey;

  /// Whether the swipe gesture is active.
  final bool enabled;

  /// Visual/action configuration for right swipe (start-to-end).
  final SwipeActionConfig? startToEndAction;

  /// Visual/action configuration for left swipe (end-to-start).
  final SwipeActionConfig? endToStartAction;

  /// Called when the user completes the right-swipe gesture.
  final VoidCallback? onStartToEndAction;

  /// Called when the user completes the left-swipe gesture.
  final VoidCallback? onEndToStartAction;

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
    final hasStartToEnd =
        widget.startToEndAction != null && widget.onStartToEndAction != null;
    final hasEndToStart =
        widget.endToStartAction != null && widget.onEndToStartAction != null;
    if (!widget.enabled || (!hasStartToEnd && !hasEndToStart)) {
      return widget.child;
    }

    return Listener(
      // Track horizontal drag distance for haptic feedback.
      // We use Listener to avoid competing with Dismissible's gesture arena.
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (_) => _resetDrag(),
      onPointerCancel: (_) => _resetDrag(),
      child: Dismissible(
        key: ValueKey('swipe-action-${widget.itemKey}'),
        direction: switch ((hasStartToEnd, hasEndToStart)) {
          (true, true) => DismissDirection.horizontal,
          (true, false) => DismissDirection.startToEnd,
          (false, true) => DismissDirection.endToStart,
          (false, false) => DismissDirection.none,
        },
        background: hasStartToEnd
            ? _SwipeActionBackground(
                action: widget.startToEndAction!,
                alignment: Alignment.centerLeft,
              )
            : const SizedBox.shrink(),
        secondaryBackground: hasEndToStart
            ? _SwipeActionBackground(
                action: widget.endToStartAction!,
                alignment: Alignment.centerRight,
              )
            : const SizedBox.shrink(),
        confirmDismiss: (direction) async {
          final config = switch (direction) {
            DismissDirection.startToEnd => widget.startToEndAction,
            DismissDirection.endToStart => widget.endToStartAction,
            _ => null,
          };
          switch (direction) {
            case DismissDirection.startToEnd:
              widget.onStartToEndAction?.call();
            case DismissDirection.endToStart:
              widget.onEndToStartAction?.call();
            case DismissDirection.horizontal:
            case DismissDirection.vertical:
            case DismissDirection.up:
            case DismissDirection.down:
            case DismissDirection.none:
              break;
          }
          return config?.dismisses ?? false;
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

  /// Fires haptic feedback once when either horizontal drag distance exceeds
  /// 15% of the widget width.
  void _onPointerMove(PointerMoveEvent event) {
    if (_hapticFired || !widget.enabled || _dragStartX == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final width = renderBox.size.width;
    final dragDelta = (_dragStartX! - event.position.dx).abs();

    if (dragDelta > width * 0.15) {
      _hapticFired = true;
      widget.onThresholdHaptic?.call();
    }
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.action,
    required this.alignment,
  });

  final SwipeActionConfig action;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: alignment == Alignment.centerRight
          ? const ValueKey('swipe-action-background')
          : const ValueKey('swipe-action-background-start'),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: action.color.withValues(alpha: 0.12),
        borderRadius: _SwipeActionWrapperState._kBorderRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Icon(action.icon, color: action.color, size: 20),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            action.label,
            style: AppTypography.label.copyWith(color: action.color),
          ),
          if (alignment == Alignment.centerRight) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(action.icon, color: action.color, size: 20),
          ],
        ],
      ),
    );
  }
}
