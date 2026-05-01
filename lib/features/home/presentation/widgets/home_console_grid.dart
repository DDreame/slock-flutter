import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';

/// A 2x2 grid of data-at-a-glance console tiles for the home page.
///
/// Each tile shows an icon, a count value, and a label. Tapping
/// navigates to the respective page.
class HomeConsoleGrid extends StatelessWidget {
  const HomeConsoleGrid({
    super.key,
    required this.items,
  });

  final List<HomeConsoleGridItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.sm,
      ),
      child: GridView.count(
        key: const ValueKey('home-console-grid'),
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.8,
        children: [
          for (final item in items)
            _ConsoleGridTile(
              key: item.tileKey,
              icon: item.icon,
              label: item.label,
              value: item.value,
              onTap: item.onTap,
              colors: colors,
            ),
        ],
      ),
    );
  }
}

@immutable
class HomeConsoleGridItem {
  const HomeConsoleGridItem({
    this.tileKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final Key? tileKey;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
}

class _ConsoleGridTile extends StatelessWidget {
  const _ConsoleGridTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    label,
                    style: AppTypography.label.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: AppTypography.headline.copyWith(
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
