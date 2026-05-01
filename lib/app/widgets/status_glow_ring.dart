import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';

/// Named constants for [StatusGlowRing] dimensions.
abstract final class GlowRingTokens {
  /// Border width of the ring.
  static const double borderWidth = 2.5;

  /// Inner padding between ring border and child.
  static const double innerPadding = 2.5;

  /// Glow shadow blur radius.
  static const double glowBlur = 8.0;

  /// Glow shadow spread radius.
  static const double glowSpread = 1.0;

  /// Glow shadow base opacity.
  static const double glowBaseAlpha = 0.4;

  /// Offline opacity.
  static const double offlineOpacity = 0.5;

  /// Breathing animation duration.
  static const Duration breathDuration = Duration(milliseconds: 1800);
}

/// Agent status for the [StatusGlowRing] indicator.
enum GlowRingStatus {
  /// Online — green ring with pulsing glow.
  online,

  /// Thinking — yellow/warning ring with pulsing glow.
  thinking,

  /// Working — primary (blue-purple) ring with pulsing glow.
  working,

  /// Error — red ring with pulsing glow.
  error,

  /// Offline — gray ring, low opacity, no glow, no animation.
  offline,
}

/// Circular status indicator with an animated breathing outer glow.
///
/// Active states (online, thinking, working, error) pulse the glow opacity
/// in a breathing pattern. Offline renders at reduced opacity with no
/// glow and no animation.
class StatusGlowRing extends StatefulWidget {
  const StatusGlowRing({
    super.key,
    required this.status,
    required this.size,
    required this.child,
  });

  /// Current agent status.
  final GlowRingStatus status;

  /// Outer diameter of the ring (includes border width).
  final double size;

  /// Content rendered inside the ring (avatar, icon, etc.).
  final Widget child;

  @override
  State<StatusGlowRing> createState() => _StatusGlowRingState();
}

class _StatusGlowRingState extends State<StatusGlowRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breathAnimation;

  bool get _isActive => widget.status != GlowRingStatus.offline;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GlowRingTokens.breathDuration,
    );
    _breathAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (_isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StatusGlowRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!_isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final ringColor = switch (widget.status) {
      GlowRingStatus.online => colors.success,
      GlowRingStatus.thinking => colors.warning,
      GlowRingStatus.working => colors.primary,
      GlowRingStatus.error => colors.error,
      GlowRingStatus.offline => colors.textTertiary,
    };

    Widget buildRing(double glowIntensity) {
      return SizedBox(
        key: const ValueKey('status-glow-ring-size'),
        width: widget.size,
        height: widget.size,
        child: Container(
          key: const ValueKey('status-glow-ring'),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ringColor,
              width: GlowRingTokens.borderWidth,
            ),
            boxShadow: _isActive
                ? [
                    BoxShadow(
                      color: ringColor.withValues(
                        alpha: GlowRingTokens.glowBaseAlpha * glowIntensity,
                      ),
                      blurRadius: GlowRingTokens.glowBlur,
                      spreadRadius: GlowRingTokens.glowSpread,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(GlowRingTokens.innerPadding),
            child: ClipOval(child: widget.child),
          ),
        ),
      );
    }

    if (!_isActive) {
      return Opacity(
        key: const ValueKey('status-glow-ring-opacity'),
        opacity: GlowRingTokens.offlineOpacity,
        child: buildRing(0),
      );
    }

    return AnimatedBuilder(
      animation: _breathAnimation,
      builder: (context, _) => buildRing(_breathAnimation.value),
    );
  }
}
