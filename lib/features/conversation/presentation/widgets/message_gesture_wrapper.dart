import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Minimum horizontal displacement (in logical pixels) required to trigger
/// a swipe-to-reply.
const double kSwipeReplyThreshold = 60;

/// Maximum horizontal offset the child can be dragged to.
const double _kMaxDragOffset = 100;

/// Duration of the spring-back animation after a swipe gesture completes.
const _kSnapBackDuration = Duration(milliseconds: 200);

/// Duration of the press-state opacity transition.
const _kPressFeedbackDuration = Duration(milliseconds: 150);

/// Opacity applied to the child while the user holds a tap.
const _kPressFeedbackOpacity = 0.7;

/// Maximum interval between two taps to count as a double-tap.
const _kDoubleTapInterval = Duration(milliseconds: 300);

/// A gesture wrapper for chat message bubbles that provides:
///
/// * **Double-tap** — e.g. quick-react with 👍 (tracked manually to avoid
///   interfering with child widget taps via [DoubleTapGestureRecognizer]).
/// * **Swipe right** — e.g. quote-reply.
/// * **Long-press** — e.g. show context menu.
/// * **Tap** — e.g. navigate to thread.
/// * **Optional press-down opacity feedback** (matches the old
///   `_TapFeedbackWrapper` behavior).
///
/// All gesture triggers fire [HapticFeedback] for tactile confirmation.
class MessageGestureWrapper extends StatefulWidget {
  const MessageGestureWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSwipeReply,
    this.enableSwipeReply = false,
    this.enablePressFeedback = false,
  });

  final Widget child;

  /// Called on a single tap (e.g. navigate to thread).
  final VoidCallback? onTap;

  /// Called when the user double-taps (e.g. quick-react).
  /// Implemented via manual timestamp tracking — does NOT use Flutter's
  /// [DoubleTapGestureRecognizer] so child widget taps are unaffected.
  final VoidCallback? onDoubleTap;

  /// Called on a long-press (e.g. context menu).
  final VoidCallback? onLongPress;

  /// Called when the user swipes right beyond [kSwipeReplyThreshold].
  final VoidCallback? onSwipeReply;

  /// When `true` the horizontal drag gesture is enabled and a reply-icon
  /// indicator appears during the swipe. When `false` swipe gestures are
  /// ignored — useful for system messages or messages with horizontally
  /// scrollable content (code blocks).
  final bool enableSwipeReply;

  /// When `true` a subtle opacity dip is shown on tap-down (press feedback).
  final bool enablePressFeedback;

  @override
  State<MessageGestureWrapper> createState() => _MessageGestureWrapperState();
}

class _MessageGestureWrapperState extends State<MessageGestureWrapper>
    with SingleTickerProviderStateMixin {
  // ---------- Swipe state ----------
  double _dragOffset = 0;
  bool _thresholdCrossed = false;
  double _dragStartX = 0;

  // ---------- Tap state ----------
  bool _isPressed = false;

  /// Timestamp of the last tap for manual double-tap detection.
  DateTime? _lastTapTime;

  // ---------- Snap-back animation ----------
  late AnimationController _snapController;
  double _snapFrom = 0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: _kSnapBackDuration,
    );
    _snapController.addListener(_onSnapTick);
  }

  void _onSnapTick() {
    if (!mounted) return;
    setState(() {
      _dragOffset = _snapFrom * (1 - _snapController.value);
    });
  }

  @override
  void dispose() {
    _snapController
      ..removeListener(_onSnapTick)
      ..dispose();
    super.dispose();
  }

  // ---------- Swipe handling ----------

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.localPosition.dx;
    _thresholdCrossed = false;
    _snapController.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (details.localPosition.dx - _dragStartX)
          .clamp(0, _kMaxDragOffset)
          .toDouble();
    });

    if (!_thresholdCrossed && _dragOffset >= kSwipeReplyThreshold) {
      _thresholdCrossed = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final crossed = _dragOffset >= kSwipeReplyThreshold;

    // Animate snap-back to zero.
    _snapFrom = _dragOffset;
    _snapController
      ..reset()
      ..forward();

    _thresholdCrossed = false;

    if (crossed) {
      widget.onSwipeReply?.call();
    }
  }

  // ---------- Tap / long-press ----------

  void _handleTapDown(TapDownDetails _) {
    if (!widget.enablePressFeedback) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!widget.enablePressFeedback) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!widget.enablePressFeedback) return;
    setState(() => _isPressed = false);
  }

  void _handleTap() {
    final now = DateTime.now();

    // Manual double-tap detection: if two taps arrive within the
    // interval, fire onDoubleTap and suppress the second onTap.
    if (widget.onDoubleTap != null &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < _kDoubleTapInterval) {
      _lastTapTime = null; // Reset to avoid triple-fire.
      HapticFeedback.lightImpact();
      widget.onDoubleTap!();
      return;
    }

    _lastTapTime = now;
    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (widget.onLongPress == null) return;
    HapticFeedback.mediumImpact();
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    Widget inner = AnimatedOpacity(
      key: const ValueKey('gesture-opacity'),
      opacity: _isPressed ? _kPressFeedbackOpacity : 1.0,
      duration: _kPressFeedbackDuration,
      child: widget.child,
    );

    // When swipe is active and offset > 0, show the reply icon + offset.
    if (widget.enableSwipeReply && _dragOffset > 0) {
      inner = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: math.min(_dragOffset / kSwipeReplyThreshold, 1.0),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.reply,
                    color: _thresholdCrossed
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: inner,
          ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onLongPress: widget.onLongPress != null ? _handleLongPress : null,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onHorizontalDragStart:
          widget.enableSwipeReply ? _onHorizontalDragStart : null,
      onHorizontalDragUpdate:
          widget.enableSwipeReply ? _onHorizontalDragUpdate : null,
      onHorizontalDragEnd:
          widget.enableSwipeReply ? _onHorizontalDragEnd : null,
      child: inner,
    );
  }
}
