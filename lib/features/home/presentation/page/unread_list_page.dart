import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_unread_item.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/application/inbox_to_home_unread_adapter.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Full-screen unread list page.
///
/// Shows all unread items backed by the canonical [InboxStore].
/// Supports pull-to-refresh, pagination (load more), and filter
/// switching (all / unread only).
class UnreadListPage extends ConsumerStatefulWidget {
  const UnreadListPage({super.key, required this.serverId});

  final String serverId;

  @override
  ConsumerState<UnreadListPage> createState() => _UnreadListPageState();
}

class _UnreadListPageState extends ConsumerState<UnreadListPage> {
  @override
  void initState() {
    super.initState();
    final state = ref.read(inboxStoreProvider);
    if (state.status == InboxStatus.initial) {
      Future.microtask(
        () => ref.read(inboxStoreProvider.notifier).load(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    final inboxState = ref.watch(inboxStoreProvider);
    final serverId = ref.watch(activeServerScopeIdProvider);

    final items = serverId != null
        ? inboxState.items
            .where((item) => item.unreadCount > 0)
            .map((item) => inboxItemToHomeUnreadItem(item, serverId: serverId))
            .toList(growable: false)
        : <HomeUnreadItem>[];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(l10n.homeCardUnread),
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        elevation: 0,
        actions: [
          _FilterChip(
            key: const ValueKey('unread-filter-chip'),
            currentFilter: inboxState.filter,
            onChanged: (filter) {
              ref.read(inboxStoreProvider.notifier).setFilter(filter);
            },
          ),
        ],
      ),
      body: _buildBody(colors, l10n, inboxState, items),
    );
  }

  Widget _buildBody(
    AppColors colors,
    AppLocalizations l10n,
    InboxState inboxState,
    List<HomeUnreadItem> items,
  ) {
    if (inboxState.status == InboxStatus.loading && items.isEmpty) {
      return const Center(
        key: ValueKey('unread-list-loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (items.isEmpty) {
      return Center(
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
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(inboxStoreProvider.notifier).refresh(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.extentAfter < 200 &&
              inboxState.hasMore) {
            ref.read(inboxStoreProvider.notifier).loadMore();
          }
          return false;
        },
        child: ListView.builder(
          key: const ValueKey('unread-list-view'),
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length + (inboxState.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= items.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            final item = items[index];
            return _UnreadListRow(
              key: ValueKey('unread-list-item-${item.id}'),
              item: item,
              colors: colors,
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.currentFilter,
    required this.onChanged,
  });

  final InboxFilter currentFilter;
  final ValueChanged<InboxFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isUnreadOnly = currentFilter == InboxFilter.unread;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        key: const ValueKey('unread-filter-toggle'),
        onTap: () {
          onChanged(
            isUnreadOnly ? InboxFilter.all : InboxFilter.unread,
          );
        },
        child: Chip(
          label: Text(
            isUnreadOnly ? 'Unread' : 'All',
            style: AppTypography.caption.copyWith(
              color: isUnreadOnly ? colors.primary : colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor:
              isUnreadOnly ? colors.primary.withValues(alpha: 0.1) : null,
          side: BorderSide(
            color: isUnreadOnly ? colors.primary : colors.border,
          ),
        ),
      ),
    );
  }
}

class _UnreadListRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final (glyph, colorFn) = _kindBadge;
    final badgeColor = colorFn(colors);

    return GestureDetector(
      onTap: () => _navigateTo(context),
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

  void _navigateTo(BuildContext context) {
    // Use typed navigation fields populated by the adapter.
    if (item.threadRouteTarget != null) {
      context.push(item.threadRouteTarget!.toLocation());
    } else if (item.channelScopeId != null) {
      final sid = item.channelScopeId!.serverId.value;
      final cid = item.channelScopeId!.value;
      context.push('/servers/$sid/channels/$cid');
    } else if (item.dmScopeId != null) {
      final sid = item.dmScopeId!.serverId.value;
      final dmId = item.dmScopeId!.value;
      context.push('/servers/$sid/dms/$dmId');
    }
  }
}
