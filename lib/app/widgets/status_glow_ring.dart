import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';

/// Agent status for the [StatusGlowRing] indicator.
enum GlowRingStatus {
  /// Online — green ring with glow.
  online,

  /// Thinking — yellow/warning ring with glow.
  thinking,

  /// Working — primary (blue-purple) ring with glow.
  working,

  /// Error — red ring with glow.
  error,

  /// Offline — gray ring, low opacity, no glow.
  offline,
}

/// Circular status indicator with an optional animated outer glow.
///
/// Wraps a [child] widget (typically an avatar) with a colored ring
/// border and an outer glow shadow matching the status color. Offline
/// state renders at reduced opacity with no glow.
class StatusGlowRing extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final ringColor = switch (status) {
      GlowRingStatus.online => colors.success,
      GlowRingStatus.thinking => colors.warning,
      GlowRingStatus.working => colors.primary,
      GlowRingStatus.error => colors.error,
      GlowRingStatus.offline => colors.textTertiary,
    };

    final hasGlow = status != GlowRingStatus.offline;

    final ring = SizedBox(
      key: const ValueKey('status-glow-ring-size'),
      width: size,
      height: size,
      child: Container(
        key: const ValueKey('status-glow-ring'),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ringColor, width: 2.5),
          boxShadow: hasGlow
              ? [
                  BoxShadow(
                    color: ringColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: ClipOval(child: child),
        ),
      ),
    );

    if (status == GlowRingStatus.offline) {
      return Opacity(
        key: const ValueKey('status-glow-ring-opacity'),
        opacity: 0.5,
        child: ring,
      );
    }

    return ring;
  }
}
