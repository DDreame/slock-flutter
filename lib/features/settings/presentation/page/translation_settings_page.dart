import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/app_loading_indicator.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Settings page for configuring message translation preferences.
///
/// Uses a [ConsumerStatefulWidget] so loading is triggered from
/// [initState] via post-frame callback, keeping [build] read-only.
class TranslationSettingsPage extends ConsumerStatefulWidget {
  const TranslationSettingsPage({super.key});

  @override
  ConsumerState<TranslationSettingsPage> createState() =>
      _TranslationSettingsPageState();
}

class _TranslationSettingsPageState
    extends ConsumerState<TranslationSettingsPage> {
  bool _loadPending = false;

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  /// Schedules a post-frame load with dedup guard to prevent stacking.
  void _scheduleLoad() {
    if (_loadPending) return;
    _loadPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPending = false;
      if (!mounted) return;
      ref.read(translationSettingsStoreProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(translationSettingsStoreProvider);
    final colors = Theme.of(context).extension<AppColors>()!;
    final hasServer = ref.watch(activeServerScopeIdProvider) != null;

    // Re-trigger load when store resets to initial (e.g. server switch).
    ref.listen(
      translationSettingsStoreProvider.select((s) => s.status),
      (prev, next) {
        if (next == TranslationSettingsStatus.initial) {
          _scheduleLoad();
        }
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Translation')),
      body: !hasServer
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
                child: Text(
                  'No active workspace. Translation settings are workspace-level.',
                  key: const ValueKey('translation-no-server'),
                  style:
                      AppTypography.body.copyWith(color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : state.status == TranslationSettingsStatus.loading
              ? const AppLoadingIndicator()
              : state.status == TranslationSettingsStatus.failure
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.failure?.userMessage(context.l10n) ??
                                context.l10n.errorUnknown,
                            style: AppTypography.body
                                .copyWith(color: colors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton(
                            key: const ValueKey('translation-retry'),
                            onPressed: () => ref
                                .read(translationSettingsStoreProvider.notifier)
                                .load(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _SettingsBody(
                      settings: state.settings,
                      colors: colors,
                    ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({
    required this.settings,
    required this.colors,
  });

  final TranslationSettings settings;
  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      children: [
        // — Translation Mode —
        Text(
          'Translation Mode',
          key: const ValueKey('translation-section-mode'),
          style: AppTypography.title.copyWith(color: colors.text),
        ),
        const SizedBox(height: AppSpacing.sm),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, mode) in TranslationMode.values.indexed) ...[
                if (index > 0) Divider(height: 1, color: colors.border),
                _TranslationModeTile(
                  key: ValueKey('translation-mode-${mode.name}'),
                  mode: mode,
                  isSelected: settings.mode == mode,
                  colors: colors,
                  onTap: () {
                    ref
                        .read(translationSettingsStoreProvider.notifier)
                        .update(settings.copyWith(mode: mode));
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        // — Preferred Language —
        Text(
          'Preferred Language',
          key: const ValueKey('translation-section-language'),
          style: AppTypography.title.copyWith(color: colors.text),
        ),
        const SizedBox(height: AppSpacing.sm),
        SectionCard(
          padding: EdgeInsets.zero,
          child: _LanguageDropdownTile(
            key: const ValueKey('translation-language-dropdown'),
            currentLanguage: settings.preferredLanguage,
            colors: colors,
            onChanged: (language) {
              ref
                  .read(translationSettingsStoreProvider.notifier)
                  .update(settings.copyWith(preferredLanguage: language));
            },
          ),
        ),
      ],
    );
  }
}

class _TranslationModeTile extends StatelessWidget {
  const _TranslationModeTile({
    super.key,
    required this.mode,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  final TranslationMode mode;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              _iconForMode(mode),
              size: 22,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleForMode(mode),
                    style: AppTypography.body.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _descriptionForMode(mode),
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 22, color: colors.primary)
            else
              Icon(Icons.circle_outlined, size: 22, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }

  static IconData _iconForMode(TranslationMode mode) {
    return switch (mode) {
      TranslationMode.auto => Icons.auto_awesome,
      TranslationMode.manual => Icons.touch_app_outlined,
      TranslationMode.off => Icons.translate,
    };
  }

  static String _titleForMode(TranslationMode mode) {
    return switch (mode) {
      TranslationMode.auto => 'Automatic',
      TranslationMode.manual => 'Manual',
      TranslationMode.off => 'Off',
    };
  }

  static String _descriptionForMode(TranslationMode mode) {
    return switch (mode) {
      TranslationMode.auto =>
        'Automatically translate messages when entering a conversation',
      TranslationMode.manual =>
        'Translate only when you tap the translate button',
      TranslationMode.off => 'Translation is disabled',
    };
  }
}

class _LanguageDropdownTile extends StatelessWidget {
  const _LanguageDropdownTile({
    super.key,
    required this.currentLanguage,
    required this.colors,
    required this.onChanged,
  });

  final String currentLanguage;
  final AppColors colors;
  final void Function(String) onChanged;

  static const _supportedLanguages = <String, String>{
    'en': 'English',
    'es': 'Español',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
    'fr': 'Français',
    'de': 'Deutsch',
    'pt': 'Português',
    'ru': 'Русский',
    'ar': 'العربية',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.language,
            size: 22,
            color: colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: DropdownButtonFormField<String>(
              key: const ValueKey('translation-language-select'),
              initialValue: _supportedLanguages.containsKey(currentLanguage)
                  ? currentLanguage
                  : 'en',
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              items: _supportedLanguages.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        e.value,
                        style: AppTypography.body.copyWith(color: colors.text),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
