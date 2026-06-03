import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:slock_app/l10n/app_localizations.dart';

AppLocalizations _conversationL10n(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));

/// Minimum horizontal displacement (in logical pixels) required to trigger
/// a swipe action.
const double kSwipeThreshold = 64;

/// Legacy alias for backward compatibility.
const double kSwipeReplyThreshold = kSwipeThreshold;

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

/// Minimum horizontal displacement before locking the gesture direction
/// (prevents conflict with vertical scrolling).
const _kDirectionLockThreshold = 15.0;

/// A gesture wrapper for chat message bubbles that provides:
///
/// * **Double-tap** — e.g. quick-react with 👍 (tracked manually to avoid
///   interfering with child widget taps via [DoubleTapGestureRecognizer]).
/// * **Swipe left** — e.g. enter thread / quote reply.
/// * **Swipe right** — e.g. quick reaction bar.
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
    this.onSwipeLeft,
    this.onSwipeRight,
    this.enableSwipeReply = false,
    this.enableSwipeLeft = false,
    this.enableSwipeRight = false,
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

  /// Optional haptic callback fired when swipe crosses threshold.
  final Future<void> Function()? onSwipeThresholdHaptic;

  /// Optional haptic callback fired on double-tap.
  final Future<void> Function()? onDoubleTapHaptic;

  /// Called when the user swipes right beyond [kSwipeThreshold].
  /// Legacy callback — use [onSwipeRight] for new code.
  final VoidCallback? onSwipeReply;

  /// Called when the user swipes left beyond [kSwipeThreshold] (drag left).
  /// Typically used for entering a thread or quote reply.
  final VoidCallback? onSwipeLeft;

  /// Called when the user swipes right beyond [kSwipeThreshold] (drag right).
  /// Typically used for showing quick reaction bar.
  final VoidCallback? onSwipeRight;

  /// When `true` the horizontal drag gesture is enabled for right-swipe
  /// (reply). Legacy flag — use [enableSwipeRight] for new code.
  final bool enableSwipeReply;

  /// When `true` left-swipe gesture is enabled (drag left → thread entry).
  final bool enableSwipeLeft;

  /// When `true` right-swipe gesture is enabled (drag right → reaction).
  final bool enableSwipeRight;

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
  bool _directionLocked = false;

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

  bool get _enableAnySwipe =>
      widget.enableSwipeReply ||
      widget.enableSwipeLeft ||
      widget.enableSwipeRight;

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
    _directionLocked = false;
    _snapController.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final rawDelta = details.localPosition.dx - _dragStartX;

    // Lock direction once past the dead zone.
    if (!_directionLocked && rawDelta.abs() >= _kDirectionLockThreshold) {
      _directionLocked = true;
    }

    if (!_directionLocked) return;

    // Determine allowed offset based on direction.
    double newOffset;
    if (rawDelta < 0) {
      // Left swipe (negative) — only if enabled.
      if (!widget.enableSwipeLeft) return;
      newOffset = rawDelta.clamp(-_kMaxDragOffset, 0).toDouble();
    } else {
      // Right swipe (positive) — enabled by either legacy or new flag.
      if (!widget.enableSwipeReply && !widget.enableSwipeRight) return;
      newOffset = rawDelta.clamp(0, _kMaxDragOffset).toDouble();
    }

    setState(() {
      _dragOffset = newOffset;
    });

    if (!_thresholdCrossed && _dragOffset.abs() >= kSwipeThreshold) {
      _thresholdCrossed = true;
      widget.onSwipeThresholdHaptic?.call();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final crossed = _dragOffset.abs() >= kSwipeThreshold;
    final wasLeftSwipe = _dragOffset < 0;

    // Animate snap-back to zero.
    _snapFrom = _dragOffset;
    _snapController
      ..reset()
      ..forward();

    _thresholdCrossed = false;
    _directionLocked = false;

    if (crossed) {
      if (wasLeftSwipe) {
        widget.onSwipeLeft?.call();
      } else {
        // Right swipe: prefer new callback, fall back to legacy.
        (widget.onSwipeRight ?? widget.onSwipeReply)?.call();
      }
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

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    Widget inner = AnimatedOpacity(
      key: const ValueKey('gesture-opacity'),
      opacity: _isPressed ? _kPressFeedbackOpacity : 1.0,
      duration: _kPressFeedbackDuration,
      child: widget.child,
    );

    // When swipe is active and offset != 0, show icon + translate.
    if (_enableAnySwipe && _dragOffset != 0) {
      final isLeftSwipe = _dragOffset < 0;
      final absOffset = _dragOffset.abs();
      final progress = math.min(absOffset / kSwipeThreshold, 1.0);

      inner = Stack(
        clipBehavior: Clip.none,
        children: [
          // Icon revealed behind the message.
          Positioned(
            left: isLeftSwipe ? null : 0,
            right: isLeftSwipe ? 0 : null,
            top: 0,
            bottom: 0,
            child: Center(
              child: Transform.scale(
                scale: 0.5 + 0.5 * progress,
                child: Opacity(
                  opacity: progress,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: isLeftSwipe ? 0 : 8,
                      right: isLeftSwipe ? 8 : 0,
                    ),
                    child: Icon(
                      isLeftSwipe ? Icons.reply : Icons.add_reaction_outlined,
                      color: _thresholdCrossed
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Translated child.
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
        if (widget.enableSwipeReply || widget.enableSwipeRight)
          CustomSemanticsAction(label: l10n.conversationReplySemantics): () {
            (widget.onSwipeRight ?? widget.onSwipeReply)?.call();
          },
        if (widget.enableSwipeLeft)
          CustomSemanticsAction(
            label: l10n.conversationSwipeLeftSemantics,
          ): () {
            widget.onSwipeLeft?.call();
          },
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onLongPress: widget.onLongPress != null ? _handleLongPress : null,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onHorizontalDragStart: _enableAnySwipe ? _onHorizontalDragStart : null,
        onHorizontalDragUpdate:
            _enableAnySwipe ? _onHorizontalDragUpdate : null,
        onHorizontalDragEnd: _enableAnySwipe ? _onHorizontalDragEnd : null,
        child: inner,
      ),
    );
  }
}
