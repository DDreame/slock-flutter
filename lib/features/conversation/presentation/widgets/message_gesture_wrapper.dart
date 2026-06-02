import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:slock_app/l10n/app_localizations.dart';

AppLocalizations _conversationL10n(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));

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
/// All gesture triggers fire haptic callbacks for tactile confirmation.
class MessageGestureWrapper extends StatefulWidget {
  const MessageGestureWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onLongPressHaptic,
    this.onSwipeReply,
    this.enableSwipeReply = false,
    this.enablePressFeedback = false,
    this.onSwipeThresholdHaptic,
    this.onDoubleTapHaptic,
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

  /// Optional haptic callback fired on long-press before [onLongPress].
  /// Should route through [HapticService] for preference-aware feedback.
  final Future<void> Function()? onLongPressHaptic;

  /// Optional haptic callback fired when swipe crosses reply threshold.
  final Future<void> Function()? onSwipeThresholdHaptic;

  /// Optional haptic callback fired on double-tap.
  final Future<void> Function()? onDoubleTapHaptic;

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

  /// Timer used to defer single-tap execution so that a second tap can
  /// cancel it and fire [onDoubleTap] instead. Without this, the first
  /// tap of an intended double-tap would immediately trigger [onTap]
  /// (e.g. navigate into a thread) before the user's second tap arrives.
  Timer? _tapTimer;

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
    _tapTimer?.cancel();
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
      widget.onSwipeThresholdHaptic?.call();
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
    // When double-tap is enabled, the first tap is deferred by the
    // double-tap interval. If a second tap arrives before the timer
    // fires, we cancel the timer and fire onDoubleTap instead.
    // This prevents premature onTap (e.g. thread navigation) from
    // firing before the user completes a double-tap.
    if (widget.onDoubleTap != null) {
      if (_tapTimer?.isActive ?? false) {
        // Second tap within interval → double-tap.
        _tapTimer!.cancel();
        _tapTimer = null;
        widget.onDoubleTapHaptic?.call();
        widget.onDoubleTap!();
        return;
      }

      // First tap → start timer. If it fires, execute single-tap.
      _tapTimer = Timer(_kDoubleTapInterval, () {
        _tapTimer = null;
        widget.onTap?.call();
      });
      return;
    }

    // No double-tap handler registered → fire onTap immediately.
    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (widget.onLongPress == null) return;
    widget.onLongPressHaptic?.call();
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

    final l10n = _conversationL10n(context);
    return Semantics(
      container: true,
      button: true,
      label: l10n.conversationMessageActionsSemantics,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        if (widget.onLongPress != null)
          CustomSemanticsAction(
            label: l10n.conversationShowMessageMenuSemantics,
          ): _handleLongPress,
        if (widget.enableSwipeReply)
          CustomSemanticsAction(label: l10n.conversationReplySemantics): () {
            widget.onSwipeReply?.call();
          },
      },
      child: GestureDetector(
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
      ),
    );
  }
}
