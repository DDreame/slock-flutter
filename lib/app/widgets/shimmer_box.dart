import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';

/// Named constants for skeleton shimmer widgets.
abstract final class SkeletonTokens {
  /// Duration of one full shimmer sweep cycle.
  static const Duration shimmerDuration = Duration(milliseconds: 1500);

  /// Default avatar placeholder diameter.
  static const double avatarSize = 40.0;

  /// Default text line placeholder height.
  static const double textLineHeight = 12.0;

  /// Spacing between text line placeholders.
  static const double textLineSpacing = 8.0;

  /// Default border radius for rectangular placeholders.
  static const double borderRadius = 6.0;

  /// Default card border radius.
  static const double cardBorderRadius = 12.0;

  /// Default card padding.
  static const double cardPadding = 16.0;

  /// Default list item height.
  static const double listItemHeight = 56.0;
}

/// Animated shimmer placeholder box used as the building block for skeleton
/// screens.
///
/// Renders a rounded rectangle with a left-to-right gradient sweep animation.
/// The base color comes from [AppColors.surfaceAlt] and the highlight from
/// [AppColors.surface], producing a subtle loading shimmer effect.
///
/// Use [ShimmerBox] directly for custom skeleton layouts, or compose with
/// [SkeletonListItem] and [SkeletonCard] for common patterns.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = SkeletonTokens.borderRadius,
  });

  /// Width of the placeholder box.
  final double width;

  /// Height of the placeholder box.
  final double height;

  /// Corner radius of the placeholder box.
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SkeletonTokens.shimmerDuration,
    );
    _animation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final baseColor = colors.surfaceAlt;
    final highlightColor = colors.surface;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          key: const ValueKey('shimmer-box'),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
