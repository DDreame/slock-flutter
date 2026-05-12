import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/widgets/shimmer_box.dart';

/// Skeleton placeholder for a list item with an avatar circle and text lines.
///
/// Mimics the layout of a typical conversation or contact list item:
/// a leading circular avatar placeholder followed by 2–3 text line
/// placeholders of varying widths.
class SkeletonListItem extends StatelessWidget {
  const SkeletonListItem({
    super.key,
    this.height = SkeletonTokens.listItemHeight,
  });

  /// Overall height of the list item placeholder.
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('skeleton-list-item'),
      height: height,
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Avatar placeholder — circular.
            ShimmerBox(
              key: ValueKey('skeleton-list-item-avatar'),
              width: SkeletonTokens.avatarSize,
              height: SkeletonTokens.avatarSize,
              borderRadius: SkeletonTokens.avatarSize / 2,
            ),
            SizedBox(width: AppSpacing.md),
            // Text line placeholders.
            Expanded(
              child: Column(
                key: ValueKey('skeleton-list-item-lines'),
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                    key: ValueKey('skeleton-list-item-line-1'),
                    width: 140,
                    height: SkeletonTokens.textLineHeight,
                  ),
                  SizedBox(height: SkeletonTokens.textLineSpacing),
                  ShimmerBox(
                    key: ValueKey('skeleton-list-item-line-2'),
                    width: 200,
                    height: SkeletonTokens.textLineHeight,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
