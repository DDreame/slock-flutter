import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/message_export_service.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_export_card.dart';

/// Bottom action bar shown during multi-select mode. (#537)
///
/// Displays Cancel, Delete, and Save buttons for batch operations
/// on the currently selected messages.
class SelectionActionBar extends ConsumerWidget {
  const SelectionActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
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
              tooltip: 'Cancel',
              onPressed: () => ref
                  .read(conversationDetailStoreProvider.notifier)
                  .exitSelectionMode(),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$selectedCount selected',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              key: const ValueKey('selection-action-save'),
              icon: const Icon(Icons.bookmark_outline),
              tooltip: 'Save',
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
                        action: 'saved',
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
              tooltip: 'Export as image',
              onPressed: selectedCount > 0
                  ? () async {
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
                      final entry = OverlayEntry(
                        builder: (_) => Transform.translate(
                          offset: const Offset(-10000, -10000),
                          child: SizedBox(
                            width: 360,
                            child: MessageExportCard(
                              messages: selectedMessages,
                              boundaryKey: boundaryKey,
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
                    }
                  : null,
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              key: const ValueKey('selection-action-delete'),
              icon: Icon(Icons.delete_outline, color: colors.error),
              tooltip: 'Delete',
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
                        action: 'deleted',
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
    if (failed == 0) {
      message = '$succeeded message${succeeded == 1 ? '' : 's'} $action.';
    } else if (succeeded == 0) {
      message = 'Failed to ${action == 'deleted' ? 'delete' : 'save'} '
          '$failed message${failed == 1 ? '' : 's'}.';
    } else {
      message = '$succeeded $action, $failed failed.';
    }

    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
