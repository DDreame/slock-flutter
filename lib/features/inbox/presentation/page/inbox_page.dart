import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/application/inbox_to_home_unread_adapter.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';

/// Full-screen inbox page.
///
/// Shows all inbox items with filter tabs (All / Unread), swipe gestures
/// (right = mark read, left = mark done), pagination, pull-to-refresh,
/// mark-all-read action, and an empty state.
class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
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
    final inboxState = ref.watch(inboxStoreProvider);

    return Scaffold(
      key: const ValueKey('inbox-page'),
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Inbox'),
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        elevation: 0,
        actions: [
          if (inboxState.status == InboxStatus.success &&
              inboxState.totalUnreadCount > 0)
            IconButton(
              key: const ValueKey('inbox-mark-all-read'),
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all read',
              onPressed: () {
                ref.read(inboxStoreProvider.notifier).markAllRead();
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _InboxFilterTabs(
            currentFilter: inboxState.filter,
            onFilterChanged: (filter) {
              ref.read(inboxStoreProvider.notifier).setFilter(filter);
            },
          ),
        ),
      ),
      body: _buildBody(colors, inboxState),
    );
  }

  Widget _buildBody(AppColors colors, InboxState inboxState) {
    if (inboxState.status == InboxStatus.loading && inboxState.items.isEmpty) {
      return const Center(
        key: ValueKey('inbox-loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (inboxState.status == InboxStatus.failure && inboxState.items.isEmpty) {
      return Center(
        key: const ValueKey('inbox-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Failed to load inbox',
              style: AppTypography.body.copyWith(color: colors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => ref.read(inboxStoreProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (inboxState.items.isEmpty) {
      return Center(
        key: const ValueKey('inbox-empty'),
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
          key: const ValueKey('inbox-list-view'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.sm,
          ),
          itemCount: inboxState.items.length + (inboxState.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= inboxState.items.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            final item = inboxState.items[index];
            return _InboxListTile(
              key: ValueKey('inbox-item-${item.channelId}'),
              item: item,
              onMarkDone: () {
                ref
                    .read(inboxStoreProvider.notifier)
                    .markDone(channelId: item.channelId);
              },
              onMarkRead: () {
                ref
                    .read(inboxStoreProvider.notifier)
                    .markRead(channelId: item.channelId);
              },
              onTap: () => _navigateToItem(item),
            );
          },
        ),
      ),
    );
  }

  void _navigateToItem(InboxItem item) {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    final homeItem = inboxItemToHomeUnreadItem(item, serverId: serverId);
    if (homeItem.threadRouteTarget != null) {
      context.push(homeItem.threadRouteTarget!.toLocation());
    } else if (homeItem.channelScopeId != null) {
      final sid = homeItem.channelScopeId!.serverId.value;
      final cid = homeItem.channelScopeId!.value;
      context.push('/servers/$sid/channels/$cid');
    } else if (homeItem.dmScopeId != null) {
      final sid = homeItem.dmScopeId!.serverId.value;
      final dmId = homeItem.dmScopeId!.value;
      context.push('/servers/$sid/dms/$dmId');
    }
  }
}

class _InboxFilterTabs extends StatelessWidget {
  const _InboxFilterTabs({
    required this.currentFilter,
    required this.onFilterChanged,
  });

  final InboxFilter currentFilter;
  final ValueChanged<InboxFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          _FilterTab(
            key: const ValueKey('inbox-filter-all'),
            label: 'All',
            isSelected: currentFilter == InboxFilter.all,
            colors: colors,
            onTap: () => onFilterChanged(InboxFilter.all),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterTab(
            key: const ValueKey('inbox-filter-unread'),
            label: 'Unread',
            isSelected: currentFilter == InboxFilter.unread,
            colors: colors,
            onTap: () => onFilterChanged(InboxFilter.unread),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    super.key,
    required this.label,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: isSelected ? colors.primary : colors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _InboxListTile extends StatelessWidget {
  const _InboxListTile({
    super.key,
    required this.item,
    required this.onMarkDone,
    required this.onMarkRead,
    required this.onTap,
  });

  final InboxItem item;
  final VoidCallback onMarkDone;
  final VoidCallback onMarkRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Dismissible(
      key: ValueKey('inbox-dismiss-${item.channelId}'),
      background: _swipeBackground(
        colors: colors,
        alignment: Alignment.centerLeft,
        icon: Icons.mark_email_read,
        color: colors.primary,
        label: 'Read',
      ),
      secondaryBackground: _swipeBackground(
        colors: colors,
        alignment: Alignment.centerRight,
        icon: Icons.done,
        color: colors.success,
        label: 'Done',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onMarkRead();
        } else {
          onMarkDone();
        }
        // Return true only for mark-done (removes from list).
        // Mark-read keeps the item visible.
        return direction == DismissDirection.endToStart;
      },
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.listItemVertical,
          ),
          child: Row(
            children: [
              _kindIcon(colors),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.channelName ?? item.channelId,
                            style: AppTypography.body.copyWith(
                              color: colors.text,
                              fontWeight: item.unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.lastActivityAt != null)
                          Text(
                            _formatTime(item.lastActivityAt!),
                            style: AppTypography.caption.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                    if (item.preview != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (item.senderName != null)
                            Text(
                              '${item.senderName}: ',
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                            ),
                          Expanded(
                            child: Text(
                              item.preview!,
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (item.unreadCount > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  key: ValueKey('inbox-unread-badge-${item.channelId}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _kindIcon(AppColors colors) {
    final (icon, color) = switch (item.kind) {
      InboxItemKind.channel => (Icons.tag, colors.success),
      InboxItemKind.dm => (Icons.chat_bubble_outline, colors.warning),
      InboxItemKind.thread => (Icons.subdirectory_arrow_right, colors.primary),
      InboxItemKind.unknown => (Icons.circle, colors.textTertiary),
    };

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  static Widget _swipeBackground({
    required AppColors colors,
    required AlignmentGeometry alignment,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.label.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.month}/${time.day}';
  }
}
