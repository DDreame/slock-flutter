import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/widgets/shimmer_box.dart';

/// Skeleton placeholder for a card with content line placeholders.
///
/// Renders a card-shaped container with 3 shimmer text lines of varying
/// widths, mimicking a typical content card loading state.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.width = double.infinity,
    this.height,
  });

  /// Width of the card. Defaults to [double.infinity] (full width).
  final double width;

  /// Optional fixed height. When null, the card sizes to its content.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      key: const ValueKey('skeleton-card'),
      width: width,
      height: height,
      padding: const EdgeInsets.all(SkeletonTokens.cardPadding),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkeletonTokens.cardBorderRadius),
        border: Border.all(color: colors.border),
      ),
      child: const Column(
        key: ValueKey('skeleton-card-lines'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title line — wider.
          ShimmerBox(
            key: ValueKey('skeleton-card-line-1'),
            width: 180,
            height: SkeletonTokens.textLineHeight + 4,
          ),
          SizedBox(height: SkeletonTokens.textLineSpacing + 4),
          // Content line 1.
          ShimmerBox(
            key: ValueKey('skeleton-card-line-2'),
            width: 240,
            height: SkeletonTokens.textLineHeight,
          ),
          SizedBox(height: SkeletonTokens.textLineSpacing),
          // Content line 2 — shorter.
          ShimmerBox(
            key: ValueKey('skeleton-card-line-3'),
            width: 160,
            height: SkeletonTokens.textLineHeight,
          ),
        ],
      ),
    );
  }
}
