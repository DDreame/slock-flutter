import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';

/// Zero-shadow surface card with border-only separation.
///
/// Used for grouping related content in settings, profiles, and
/// list sections. No elevation — depth comes from the color hierarchy.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.padding,
    required this.child,
  });

  /// Optional custom padding. Defaults to [AppSpacing.cardPadding].
  final EdgeInsetsGeometry? padding;

  /// Card content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      key: const ValueKey('section-card'),
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: child,
    );
  }
}
