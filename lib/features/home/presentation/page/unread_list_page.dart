import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_unread_item.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

/// Full-screen unread list page.
///
/// Shows all unread items (no cap at 5) backed by the same
/// [HomeUnreadItem] aggregation as the Home card.
class UnreadListPage extends ConsumerWidget {
  const UnreadListPage({super.key, required this.serverId});

  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    final state = ref.watch(homeListStoreProvider);
    final unreadState = ref.watch(channelUnreadStoreProvider);

    final items = buildUnreadItems(
      threadItems: state.threadItems,
      channels: [...state.pinnedChannels, ...state.channels],
      directMessages: [
        ...state.pinnedDirectMessages,
        ...state.directMessages,
      ],
      unreadState: unreadState,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(l10n.homeCardUnread),
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        elevation: 0,
      ),
      body: items.isEmpty
          ? Center(
              key: const ValueKey('unread-list-empty'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 48,
                    color: colors.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.homeCardUnreadEmpty,
                    style: AppTypography.body.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              key: const ValueKey('unread-list-view'),
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _UnreadListRow(
                  key: ValueKey('unread-list-item-${item.id}'),
                  item: item,
                  colors: colors,
                );
              },
            ),
    );
  }
}

class _UnreadListRow extends ConsumerWidget {
  const _UnreadListRow({
    super.key,
    required this.item,
    required this.colors,
  });

  final HomeUnreadItem item;
  final AppColors colors;

  (String glyph, Color Function(AppColors) colorFn) get _kindBadge {
    switch (item.kind) {
      case HomeUnreadKind.thread:
        return ('\u21a9', (c) => c.primary);
      case HomeUnreadKind.channel:
        return ('#', (c) => c.success);
      case HomeUnreadKind.directMessage:
        return ('\u2709', (c) => c.warning);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (glyph, colorFn) = _kindBadge;
    final badgeColor = colorFn(colors);

    return GestureDetector(
      onTap: () => _navigateTo(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                glyph,
                style: TextStyle(
                  fontSize: 12,
                  color: badgeColor,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.sourceLabel ?? item.title,
                    style: AppTypography.body.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.preview != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.preview!,
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.unreadCount > 99 ? '99+' : '${item.unreadCount}',
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, WidgetRef ref) {
    switch (item.kind) {
      case HomeUnreadKind.thread:
        if (item.threadRouteTarget != null) {
          context.push(item.threadRouteTarget!.toLocation());
        }
      case HomeUnreadKind.channel:
        if (item.channelScopeId != null) {
          ref.read(markChannelReadUseCaseProvider)(
            item.channelScopeId!,
          );
          final sid = item.channelScopeId!.serverId.routeParam;
          final cid = item.channelScopeId!.routeParam;
          context.push('/servers/$sid/channels/$cid');
        }
      case HomeUnreadKind.directMessage:
        if (item.dmScopeId != null) {
          ref.read(markDmReadUseCaseProvider)(item.dmScopeId!);
          final sid = item.dmScopeId!.serverId.routeParam;
          final did = item.dmScopeId!.routeParam;
          context.push('/servers/$sid/dms/$did');
        }
    }
  }
}
