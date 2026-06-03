import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/message_export_service.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_export_card.dart';
import 'package:slock_app/l10n/app_localizations.dart';

AppLocalizations _conversationL10n(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));

/// Bottom action bar shown during multi-select mode. (#537)
///
/// Displays Cancel, Delete, and Save buttons for batch operations
/// on the currently selected messages.
class SelectionActionBar extends ConsumerStatefulWidget {
  const SelectionActionBar({super.key});

  @override
  ConsumerState<SelectionActionBar> createState() => _SelectionActionBarState();
}

class _SelectionActionBarState extends ConsumerState<SelectionActionBar> {
  /// Re-entry guard: prevents double-tap spawning concurrent captures (#857).
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = _conversationL10n(context);
    final selectedCount = ref.watch(
      conversationDetailStoreProvider
          .select((s) => s.selectedMessageIds.length),
    );

    return Container(
      key: const ValueKey('selection-action-bar'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('selection-action-cancel'),
              icon: const Icon(Icons.close),
              tooltip: l10n.conversationSelectionCancel,
              onPressed: () => ref
                  .read(conversationDetailStoreProvider.notifier)
                  .exitSelectionMode(),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.conversationSelectionSelected(selectedCount),
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              key: const ValueKey('selection-action-save'),
              icon: const Icon(Icons.bookmark_outline),
              tooltip: l10n.conversationSelectionSave,
              onPressed: selectedCount > 0
                  ? () async {
                      final ids = Set<String>.of(ref
                          .read(conversationDetailStoreProvider)
                          .selectedMessageIds);
                      final result = await ref
                          .read(conversationDetailStoreProvider.notifier)
                          .batchSaveMessages(ids);
                      if (!context.mounted) return;
                      _showBatchResultSnackbar(
                        context,
                        action: l10n.conversationSelectionActionSaved,
                        succeeded: result.succeeded,
                        failed: result.failed,
                      );
                    }
                  : null,
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              key: const ValueKey('selection-action-export'),
              icon: const Icon(Icons.image_outlined),
              tooltip: l10n.conversationSelectionExportAsImage,
              onPressed: selectedCount > 0 && !_isExporting
                  ? () async {
                      if (_isExporting) return; // Re-entry guard (#857).
                      setState(() => _isExporting = true);
                      try {
                        // Gather selected messages in chronological order.
                        final detailState =
                            ref.read(conversationDetailStoreProvider);
                        final ids = detailState.selectedMessageIds;
                        final selectedMessages = detailState.messages
                            .where((m) => ids.contains(m.id))
                            .toList()
                          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

                        if (selectedMessages.isEmpty) return;

                        // Render the export card in an overlay for capture.
                        final boundaryKey = GlobalKey();
                        final overlay = Overlay.of(context);
                        // Capture the theme from the current context so the
                        // overlay (which has its own context) renders text
                        // with the correct font family and styles.
                        final theme = Theme.of(context);
                        final entry = OverlayEntry(
                          builder: (_) => Theme(
                            data: theme,
                            child: Transform.translate(
                              offset: const Offset(-10000, -10000),
                              child: SizedBox(
                                width: 360,
                                child: MessageExportCard(
                                  messages: selectedMessages,
                                  boundaryKey: boundaryKey,
                                ),
                              ),
                            ),
                          ),
                        );
                        overlay.insert(entry);

                        // Wait for the overlay to be laid out and painted.
                        // addPostFrameCallback fires after the next frame renders.
                        final completer = Completer<void>();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          completer.complete();
                        });
                        await completer.future;

                        // Mounted check after async gap (#857).
                        if (!context.mounted) {
                          entry.remove();
                          return;
                        }

                        // Capture and share.
                        final service = ref.read(messageExportServiceProvider);
                        await service.exportSelectedMessages(
                          selectedMessages,
                          boundaryKey: boundaryKey,
                        );

                        // Clean up overlay.
                        entry.remove();

                        // Exit selection mode.
                        if (context.mounted) {
                          ref
                              .read(conversationDetailStoreProvider.notifier)
                              .exitSelectionMode();
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isExporting = false);
                        }
                      }
                    }
                  : null,
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              key: const ValueKey('selection-action-save-gallery'),
              icon: const Icon(Icons.save_alt),
              tooltip: l10n.conversationSelectionSaveToGallery,
              onPressed: selectedCount > 0 && !_isExporting
                  ? () async {
                      if (_isExporting) return; // Re-entry guard (#857).
                      setState(() => _isExporting = true);
                      try {
                        // Gather selected messages in chronological order.
                        final detailState =
                            ref.read(conversationDetailStoreProvider);
                        final ids = detailState.selectedMessageIds;
                        final selectedMessages = detailState.messages
                            .where((m) => ids.contains(m.id))
                            .toList()
                          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

                        if (selectedMessages.isEmpty) return;

                        // Render the export card in an overlay for capture.
                        final boundaryKey = GlobalKey();
                        final overlay = Overlay.of(context);
                        final theme = Theme.of(context);
                        final entry = OverlayEntry(
                          builder: (_) => Theme(
                            data: theme,
                            child: Transform.translate(
                              offset: const Offset(-10000, -10000),
                              child: SizedBox(
                                width: 360,
                                child: MessageExportCard(
                                  messages: selectedMessages,
                                  boundaryKey: boundaryKey,
                                ),
                              ),
                            ),
                          ),
                        );
                        overlay.insert(entry);

                        // Wait for layout.
                        final completer = Completer<void>();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          completer.complete();
                        });
                        await completer.future;

                        // Mounted check after async gap (#857).
                        if (!context.mounted) {
                          entry.remove();
                          return;
                        }

                        // Save to gallery.
                        final service = ref.read(messageExportServiceProvider);
                        final path = await service.saveExportToGallery(
                          boundaryKey: boundaryKey,
                        );

                        // Clean up overlay.
                        entry.remove();

                        if (!context.mounted) return;
                        if (path != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(l10n.conversationSelectionSavedToGallery),
                            ),
                          );
                          ref
                              .read(conversationDetailStoreProvider.notifier)
                              .exitSelectionMode();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  l10n.conversationSelectionSaveGalleryFailed),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isExporting = false);
                        }
                      }
                    }
                  : null,
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              key: const ValueKey('selection-action-delete'),
              icon: Icon(Icons.delete_outline, color: colors.error),
              tooltip: l10n.conversationSelectionDelete,
              onPressed: selectedCount > 0
                  ? () async {
                      final ids = Set<String>.of(ref
                          .read(conversationDetailStoreProvider)
                          .selectedMessageIds);
                      final result = await ref
                          .read(conversationDetailStoreProvider.notifier)
                          .batchDeleteMessages(ids);
                      if (!context.mounted) return;
                      _showBatchResultSnackbar(
                        context,
                        action: l10n.conversationSelectionActionDeleted,
                        succeeded: result.succeeded,
                        failed: result.failed,
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showBatchResultSnackbar(
    BuildContext context, {
    required String action,
    required int succeeded,
    required int failed,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final String message;
    final l10n = _conversationL10n(context);
    if (failed == 0) {
      message = l10n.conversationSelectionBatchSucceeded(succeeded, action);
    } else if (succeeded == 0) {
      final verb = action == l10n.conversationSelectionActionDeleted
          ? l10n.conversationSelectionActionDeleteVerb
          : l10n.conversationSelectionActionSaveVerb;
      message = l10n.conversationSelectionBatchFailed(verb, failed);
    } else {
      message = l10n.conversationSelectionBatchPartial(
        succeeded,
        action,
        failed,
      );
    }

    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
