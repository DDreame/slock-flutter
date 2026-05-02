import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Placeholder DMs tab.
///
/// Task #329 will extract the DM list from [HomePage]
/// into this page.
class DmsTabPage extends StatelessWidget {
  const DmsTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dmsTabTitle)),
      body: Center(
        key: const ValueKey('dms-tab-placeholder'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: colors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.dmsTabHeadline,
              style: AppTypography.headline.copyWith(
                color: colors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.dmsTabPlaceholder,
              style: AppTypography.body.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
