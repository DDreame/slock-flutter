import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/translation/application/translation_cache_store.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Overlay widget that wraps message content and shows either the
/// original or the translated version, with a status indicator and
/// a toggle button.
///
/// INV-TRANSLATE-1: translation never replaces original — both are
/// available via toggle.
/// INV-TRANSLATE-2: translation status is always visible (spinner
/// for pending, error icon for failed).
class TranslatedContentOverlay extends ConsumerWidget {
  const TranslatedContentOverlay({
    super.key,
    required this.messageId,
    required this.originalChild,
    required this.translatedContent,
    required this.entry,
  });

  /// Build counter for rebuild-isolation tests.
  /// Incremented only inside assert() — zero-cost in release builds.
  @visibleForTesting
  static int debugBuildCount = 0;

  /// The message this overlay belongs to.
  final String messageId;

  /// The original message content widget (always available).
  final Widget originalChild;

  /// Pre-rendered translated content (null if not yet available).
  final String? translatedContent;

  /// The cached translation entry with status information.
  final TranslationEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(() {
      TranslatedContentOverlay.debugBuildCount++;
      return true;
    }());
    final colors = Theme.of(context).extension<AppColors>()!;
    // INV-TAB-SORT-CACHE-1 pattern: .select() ensures this widget only
    // rebuilds when THIS message's showTranslation flag changes, not when
    // any other message in the cache is updated.
    final isShowingTranslation = ref.watch(
      translationCacheStoreProvider
          .select((s) => s.showTranslation[messageId] ?? false),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show original or translated content based on toggle state.
        if (isShowingTranslation &&
            entry.status != TranslationEntryStatus.failed &&
            translatedContent != null)
          Text(
            translatedContent!,
            key: const ValueKey('translated-content'),
            style: AppTypography.body.copyWith(color: colors.text),
          )
        else
          originalChild,

        const SizedBox(height: AppSpacing.xs),

        // Status indicator row.
        _TranslationStatusRow(
          key: ValueKey('translation-status-$messageId'),
          messageId: messageId,
          entry: entry,
          isShowingTranslation: isShowingTranslation,
          colors: colors,
        ),
      ],
    );
  }
}

class _TranslationStatusRow extends ConsumerWidget {
  const _TranslationStatusRow({
    super.key,
    required this.messageId,
    required this.entry,
    required this.isShowingTranslation,
    required this.colors,
  });

  final String messageId;
  final TranslationEntry entry;
  final bool isShowingTranslation;
  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status icon.
        if (entry.status == TranslationEntryStatus.pending)
          SizedBox(
            key: const ValueKey('translation-pending-spinner'),
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colors.textTertiary,
            ),
          )
        else if (entry.status == TranslationEntryStatus.failed)
          Icon(
            Icons.error_outline,
            key: const ValueKey('translation-failed-icon'),
            size: 14,
            color: colors.error,
          )
        else
          Icon(
            Icons.translate,
            key: const ValueKey('translation-done-icon'),
            size: 14,
            color: colors.textTertiary,
          ),

        const SizedBox(width: 4),

        // Toggle button.
        if (entry.status == TranslationEntryStatus.translated)
          TextButton(
            key: const ValueKey('translation-toggle'),
            style: _translationTextButtonStyle(colors.primary),
            onPressed: () => ref
                .read(translationCacheStoreProvider.notifier)
                .toggleTranslation(messageId),
            child: Text(
              isShowingTranslation ? 'Show original' : 'Show translation',
            ),
          )
        else if (entry.status == TranslationEntryStatus.pending)
          Text(
            'Translating…',
            key: const ValueKey('translation-pending-text'),
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
            ),
          )
        else
          TextButton(
            key: const ValueKey('translation-retry'),
            style: _translationTextButtonStyle(colors.error),
            onPressed: () => ref
                .read(translationCacheStoreProvider.notifier)
                .translateMessage(messageId),
            child: Text(context.l10n.translationFailed),
          ),
      ],
    );
  }
}

ButtonStyle _translationTextButtonStyle(Color foregroundColor) {
  return TextButton.styleFrom(
    foregroundColor: foregroundColor,
    minimumSize: const Size(48, 48),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    tapTargetSize: MaterialTapTargetSize.padded,
    textStyle: AppTypography.caption,
  );
}
