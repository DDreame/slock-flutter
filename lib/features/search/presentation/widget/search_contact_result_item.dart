import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/presentation/widget/search_result_item.dart';

/// A search result item for contact/identity matches.
class SearchContactResultItem extends StatelessWidget {
  const SearchContactResultItem({
    super.key,
    required this.result,
    required this.query,
    required this.onTap,
  });

  final SearchContactResult result;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>();

    return InkWell(
      key: ValueKey('search-contact-result-${result.identityId}'),
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
            // Avatar circle with initial
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  (colors?.primary ?? theme.colorScheme.primary).withAlpha(26),
              child: Text(
                result.displayName.characters.first.toUpperCase(),
                style: AppTypography.body.copyWith(
                  color: colors?.primary ?? theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Display name with highlight
            Expanded(
              child: _HighlightedContactName(
                name: result.displayName,
                query: query,
                baseStyle: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colors?.text ?? theme.colorScheme.onSurface,
                ),
                highlightColor: const Color(0x1AF59E0B),
              ),
            ),
            // Icon indicator
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colors?.textTertiary ?? theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedContactName extends StatelessWidget {
  const _HighlightedContactName({
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
