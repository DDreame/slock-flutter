import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';

// ---------------------------------------------------------------------------
// #509: Empty inbox widget — "All caught up!" state per Z2 mockup.
// ---------------------------------------------------------------------------

/// Full-screen empty state shown when the inbox has no items.
///
/// Center column with icon, title, and description text.
class EmptyInboxWidget extends StatelessWidget {
  const EmptyInboxWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 56,
            color: colors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'All caught up!',
            style: AppTypography.title.copyWith(color: colors.text),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No messages in your inbox',
            style: AppTypography.body.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}
