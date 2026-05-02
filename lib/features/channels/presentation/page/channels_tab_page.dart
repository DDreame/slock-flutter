import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Placeholder Channels tab.
///
/// Task #328 will extract the channel list from [HomePage]
/// into this page.
class ChannelsTabPage extends StatelessWidget {
  const ChannelsTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.channelsTabTitle)),
      body: Center(
        key: const ValueKey('channels-tab-placeholder'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tag,
              size: 48,
              color: colors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.channelsTabTitle,
              style: AppTypography.headline.copyWith(
                color: colors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.channelsTabPlaceholder,
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
