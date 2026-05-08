import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/share/data/shared_content.dart';

/// Shows a compact preview of the [SharedContent] being shared.
///
/// Displays combined text (if any) and an attachment count summary.
class SharePreviewCard extends StatelessWidget {
  const SharePreviewCard({super.key, required this.content});

  final SharedContent content;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final combinedText = content.combinedText;
    final attachments = content.attachmentItems;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.sm,
      ),
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (combinedText.isNotEmpty)
              Text(
                combinedText,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(color: colors.text),
              ),
            if (attachments.isNotEmpty) ...[
              if (combinedText.isNotEmpty)
                const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.attach_file,
                      size: 16, color: colors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    attachments.length == 1
                        ? '1 attachment'
                        : '${attachments.length} attachments',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
