import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/presentation/widgets/search_result_item.dart';

/// A search result item for channel/DM matches.
class SearchChannelResultItem extends StatelessWidget {
  const SearchChannelResultItem({
    super.key,
    required this.result,
    required this.query,
    required this.onTap,
  });

  final SearchChannelResult result;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>();
    final isDm = result.surface == 'direct_message';

    return InkWell(
      key: ValueKey('search-channel-result-${result.channelId}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: colors?.border ?? theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Avatar: # for channel, person icon for DM
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDm
                    ? (colors?.primary ?? theme.colorScheme.primary)
                        .withAlpha(26)
                    : (colors?.primary ?? theme.colorScheme.primary)
                        .withAlpha(26),
                borderRadius: BorderRadius.circular(isDm ? 18 : 8),
              ),
              alignment: Alignment.center,
              child: Text(
                isDm ? result.channelName.characters.first.toUpperCase() : '#',
                style: AppTypography.body.copyWith(
                  color: colors?.primary ?? theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightedName(
                    name: isDm ? result.channelName : '#${result.channelName}',
                    query: query,
                    baseStyle: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors?.text ?? theme.colorScheme.onSurface,
                    ),
                    highlightColor: const Color(0x1AF59E0B),
                  ),
                  if (result.lastMessagePreview != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      result.lastMessagePreview!,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors?.textSecondary ??
                            theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Surface badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (colors?.surfaceAlt ??
                    theme.colorScheme.surfaceContainerLow),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isDm ? 'DM' : 'Channel',
                style: AppTypography.caption.copyWith(
                  color: colors?.textTertiary ??
                      theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedName extends StatelessWidget {
  const _HighlightedName({
    required this.name,
    required this.query,
    required this.baseStyle,
    required this.highlightColor,
  });

  final String name;
  final String query;
  final TextStyle baseStyle;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(name, style: baseStyle);
    }
    return Text.rich(
      buildHighlightedSpan(name, query, baseStyle, highlightColor),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
