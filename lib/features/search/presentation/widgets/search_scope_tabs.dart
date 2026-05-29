import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Segmented control for switching between search scopes.
class SearchScopeTabs extends StatelessWidget {
  const SearchScopeTabs({
    super.key,
    required this.activeScope,
    required this.onScopeChanged,
    this.messageCount,
    this.channelCount,
    this.contactCount,
  });

  final SearchScope activeScope;
  final ValueChanged<SearchScope> onScopeChanged;
  final int? messageCount;
  final int? channelCount;
  final int? contactCount;

  static final _kOuterBorderRadius = BorderRadius.circular(8);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();
    final surfaceAlt =
        colors?.surfaceAlt ?? Theme.of(context).colorScheme.surfaceContainerLow;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: surfaceAlt,
        borderRadius: _kOuterBorderRadius,
      ),
      child: Row(
        children: [
          _ScopeTab(
            key: const ValueKey('search-scope-all'),
            label: context.l10n.searchScopeAll,
            count: null,
            isActive: activeScope == SearchScope.all,
            onTap: () => onScopeChanged(SearchScope.all),
          ),
          _ScopeTab(
            key: const ValueKey('search-scope-messages'),
            label: context.l10n.searchScopeMessages,
            count: messageCount,
            countKey: const ValueKey('search-scope-messages-count'),
            isActive: activeScope == SearchScope.messages,
            onTap: () => onScopeChanged(SearchScope.messages),
          ),
          _ScopeTab(
            key: const ValueKey('search-scope-channels'),
            label: context.l10n.searchScopeChannels,
            count: channelCount,
            countKey: const ValueKey('search-scope-channels-count'),
            isActive: activeScope == SearchScope.channels,
            onTap: () => onScopeChanged(SearchScope.channels),
          ),
          _ScopeTab(
            key: const ValueKey('search-scope-contacts'),
            label: context.l10n.searchScopeContacts,
            count: contactCount,
            countKey: const ValueKey('search-scope-contacts-count'),
            isActive: activeScope == SearchScope.contacts,
            onTap: () => onScopeChanged(SearchScope.contacts),
          ),
        ],
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    super.key,
    required this.label,
    required this.count,
    this.countKey,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final int? count;
  final Key? countKey;
  final bool isActive;
  final VoidCallback onTap;

  static final _kTabBorderRadius = BorderRadius.circular(6);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();
    final surface = colors?.surface ?? Theme.of(context).colorScheme.surface;
    final shadowColor = colors?.shadowLight ?? Colors.black.withAlpha(13);
    final textColor = isActive
        ? (colors?.text ?? Theme.of(context).colorScheme.onSurface)
        : (colors?.textSecondary ??
            Theme.of(context).colorScheme.onSurfaceVariant);

    return Expanded(
      child: Semantics(
        button: true,
        label: context.l10n.searchScopeTabSemantics(label),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? surface : Colors.transparent,
              borderRadius: _kTabBorderRadius,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.label.copyWith(
                      color: textColor,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 2),
                  Text(
                    '($count)',
                    key: countKey,
                    style: AppTypography.caption.copyWith(
                      color: textColor.withAlpha(179),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
