import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/features/home/application/conversation_swipe_preference.dart';
import 'package:slock_app/features/settings/data/theme_preference.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeModeStoreProvider);
    final swipePreference = ref.watch(conversationSwipePreferenceProvider);
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
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.l10n.settingsAppearanceSwipeSection,
            key: const ValueKey('appearance-section-swipes'),
            style: AppTypography.title.copyWith(color: colors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SwipeActionOptionTile(
                  key: const ValueKey('swipe-left-option'),
                  title: context.l10n.settingsSwipeLeftTitle,
                  description: context.l10n.settingsSwipeLeftDescription,
                  action: swipePreference.left,
                  colors: colors,
                  onChanged: ref
                      .read(conversationSwipePreferenceProvider.notifier)
                      .setLeftAction,
                ),
                Divider(height: 1, color: colors.border),
                _SwipeActionOptionTile(
                  key: const ValueKey('swipe-right-option'),
                  title: context.l10n.settingsSwipeRightTitle,
                  description: context.l10n.settingsSwipeRightDescription,
                  action: swipePreference.right,
                  colors: colors,
                  onChanged: ref
                      .read(conversationSwipePreferenceProvider.notifier)
                      .setRightAction,
                ),
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

class _SwipeActionOptionTile extends StatelessWidget {
  const _SwipeActionOptionTile({
    super.key,
    required this.title,
    required this.description,
    required this.action,
    required this.colors,
    required this.onChanged,
  });

  final String title;
  final String description;
  final ConversationSwipeAction action;
  final AppColors colors;
  final ValueChanged<ConversationSwipeAction> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title:
          Text(title, style: AppTypography.body.copyWith(color: colors.text)),
      subtitle: Text(
        description,
        style: AppTypography.caption.copyWith(color: colors.textSecondary),
      ),
      trailing: Text(
        _labelForAction(action, context.l10n),
        style: AppTypography.label.copyWith(color: colors.primary),
      ),
      onTap: () => _showPicker(context),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<ConversationSwipeAction>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in ConversationSwipeAction.values)
                ListTile(
                  key: ValueKey('swipe-action-${option.name}'),
                  leading: option == action
                      ? const Icon(Icons.check_circle)
                      : const Icon(Icons.circle_outlined),
                  title: Text(_labelForAction(option, context.l10n)),
                  onTap: () => Navigator.of(context).pop(option),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null) onChanged(selected);
  }

  static String _labelForAction(
    ConversationSwipeAction action,
    AppLocalizations l10n,
  ) {
    return switch (action) {
      ConversationSwipeAction.none => l10n.conversationSwipeActionNone,
      ConversationSwipeAction.archive => l10n.conversationSwipeActionArchive,
      ConversationSwipeAction.togglePin => l10n.conversationSwipeActionPin,
      ConversationSwipeAction.toggleMute => l10n.conversationSwipeActionMute,
    };
  }
}
