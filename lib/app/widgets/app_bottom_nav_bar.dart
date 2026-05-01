import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';

/// A single navigation destination in [AppBottomNavBar].
@immutable
class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  /// Line-style icon shown when inactive.
  final IconData icon;

  /// Filled icon shown when active.
  final IconData activeIcon;

  /// Short text label beneath the icon.
  final String label;
}

/// Lightweight bottom navigation bar using Z3 design tokens.
///
/// Renders line icons with small text labels, styled from [AppColors] and
/// [AppTypography]. Does NOT use Material's [NavigationBar] or
/// [BottomNavigationBar] widgets.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  /// The index of the currently active destination.
  final int currentIndex;

  /// Called when a destination is tapped.
  final ValueChanged<int> onTap;

  /// The navigation destinations to render.
  final List<AppBottomNavItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      key: const ValueKey('app-bottom-nav-bar'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavItem(
                    item: items[i],
                    isActive: i == currentIndex,
                    colors: colors,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.isActive,
    required this.colors,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool isActive;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? colors.primary : colors.textTertiary;
    final icon = isActive ? item.activeIcon : item.icon;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.label,
              style: AppTypography.caption.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
