import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/share/application/share_upload_state.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Shows per-file upload progress during the share-send flow.
///
/// Watches [shareUploadStateProvider] and renders a linear progress bar
/// with file count and percentage when [ShareUploadState.isUploading] is true.
/// Hidden when no upload is in progress.
class ShareUploadProgressIndicator extends ConsumerWidget {
  const ShareUploadProgressIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(shareUploadStateProvider);
    if (!uploadState.isUploading) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<AppColors>()!;
    final fileLabel = uploadState.totalFiles > 1
        ? context.l10n.shareUploadProgressMulti(
            uploadState.currentFileIndex + 1,
            uploadState.totalFiles,
          )
        : context.l10n.shareUploadProgressSingle;
    final percent = (uploadState.overallProgress * 100).toInt();

    return Container(
      key: const ValueKey('share-upload-progress'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                fileLabel,
                style: AppTypography.label.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Text(
                '$percent%',
                style: AppTypography.label.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: uploadState.overallProgress,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
