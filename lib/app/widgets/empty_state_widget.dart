import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';

/// Shared empty-state widget for screens with no data.
///
/// Replaces the repeated `Center(child: Column(icon, title, subtitle))`
/// patterns across 24+ pages (#642).
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  /// Leading icon shown above the title.
  final IconData icon;

  /// Primary message (e.g. "No saved messages").
  final String title;

  /// Optional secondary line explaining next steps.
  final String? subtitle;

  /// Optional action widget (e.g. a button to clear filters).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();
    final textColor = colors?.text;
    final secondaryColor = colors?.textSecondary;
    final iconColor = colors?.textTertiary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(color: textColor),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: secondaryColor),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
