import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/features/settings/data/theme_preference.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeModeStoreProvider);
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsAppearanceTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          Text(
            context.l10n.settingsAppearanceThemeSection,
            key: const ValueKey('appearance-section-theme'),
            style: AppTypography.title.copyWith(color: colors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (index, pref) in ThemePreference.values.indexed) ...[
                  if (index > 0) Divider(height: 1, color: colors.border),
                  _ThemeOptionTile(
                    key: ValueKey('theme-option-${pref.name}'),
                    preference: pref,
                    isSelected: themeState.preference == pref,
                    colors: colors,
                    onTap: () {
                      ref
                          .read(themeModeStoreProvider.notifier)
                          .setPreference(pref);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    super.key,
    required this.preference,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  final ThemePreference preference;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              _iconForPreference(preference),
              size: 22,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleForPreference(preference, l10n),
                    style: AppTypography.body.copyWith(
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _descriptionForPreference(preference, l10n),
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 22,
                color: colors.primary,
              )
            else
              Icon(
                Icons.circle_outlined,
                size: 22,
                color: colors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForPreference(ThemePreference pref) {
    return switch (pref) {
      ThemePreference.system => Icons.settings_brightness,
      ThemePreference.light => Icons.light_mode_outlined,
      ThemePreference.dark => Icons.dark_mode_outlined,
    };
  }

  static String _titleForPreference(
      ThemePreference pref, AppLocalizations l10n) {
    return switch (pref) {
      ThemePreference.system => l10n.settingsThemeSystemTitle,
      ThemePreference.light => l10n.settingsThemeLightTitle,
      ThemePreference.dark => l10n.settingsThemeDarkTitle,
    };
  }

  static String _descriptionForPreference(
      ThemePreference pref, AppLocalizations l10n) {
    return switch (pref) {
      ThemePreference.system => l10n.settingsThemeSystemDescription,
      ThemePreference.light => l10n.settingsThemeLightDescription,
      ThemePreference.dark => l10n.settingsThemeDarkDescription,
    };
  }
}
