import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/list_action_sheet.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/presentation/widget/empty_inbox_widget.dart';
import 'package:slock_app/features/inbox/presentation/widget/inbox_item_tile.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// #509: Inbox page redesign — Z2 mockup.
//
// 3-tab filter (Unread | @Mentions | All), redesigned InboxItemTile,
// bidirectional swipe (left=mark read, right=done), EmptyInboxWidget.
// ---------------------------------------------------------------------------

/// Full-screen inbox page.
///
/// Shows all inbox items with filter tabs (Unread / @Mentions / All),
/// swipe gestures (left = mark read, right = mark done), pagination,
/// pull-to-refresh, mark-all-read action, and an empty state.
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
        () =>
            ref.read(inboxStoreProvider.notifier).setFilter(InboxFilter.unread),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final inboxState = ref.watch(inboxStoreProvider);
    // INV-NET-DEGRADE-2: surface refresh failure via snackbar only when a
    // refresh completes with failure — not on mutation errors.
    ref.listen(
      inboxStoreProvider.select((s) => s.isRefreshing),
      (prev, next) {
        if (prev == true && next == false) {
          final s = ref.read(inboxStoreProvider);
          if (s.failure != null && s.status == InboxStatus.success) {
            _showRefreshFailedSnackBar();
          }
        }
      },
    );

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
    // Skeleton: loading/initial with no items to display.
    // Uses items.isEmpty (not projections.isEmpty) to avoid triggering
    // inboxProjectionProvider → homeListStoreProvider during initial load.
    // After #510 fix 1 (InboxStore clears items on filter switch),
    // items.isEmpty is true during filter-switch loading.
    if ((inboxState.status == InboxStatus.initial ||
            inboxState.status == InboxStatus.loading) &&
        inboxState.items.isEmpty) {
      return ListView(
        key: const ValueKey('inbox-skeleton'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.sm,
        ),
        children: const [
          SkeletonListItem(key: ValueKey('inbox-skeleton-item-0')),
          SkeletonListItem(key: ValueKey('inbox-skeleton-item-1')),
          SkeletonListItem(key: ValueKey('inbox-skeleton-item-2')),
          SkeletonListItem(key: ValueKey('inbox-skeleton-item-3')),
          SkeletonListItem(key: ValueKey('inbox-skeleton-item-4')),
        ],
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
      return const EmptyInboxWidget(key: ValueKey('inbox-empty'));
    }

    final projections = ref.watch(inboxProjectionProvider);
    final items = inboxState.items;

    return Column(
      children: [
        if (inboxState.isRefreshing)
          const LinearProgressIndicator(
            key: ValueKey('inbox-refreshing'),
            minHeight: 2,
          ),
        Expanded(
          child: RefreshIndicator(
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
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: projections.length + (inboxState.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= projections.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final projection = projections[index];
                  final channelId = projection.channelId ?? projection.id;
                  // Look up isMentioned from the original InboxItem.
                  final isMentioned =
                      index < items.length ? items[index].isMentioned : false;

                  return _SwipeableInboxItem(
                    key: ValueKey('inbox-item-$channelId'),
                    channelId: channelId,
                    projection: projection,
                    isMentioned: isMentioned,
                    onMarkRead: () {
                      ref
                          .read(inboxStoreProvider.notifier)
                          .markRead(channelId: channelId);
                    },
                    onMarkDone: () {
                      ref
                          .read(inboxStoreProvider.notifier)
                          .markDone(channelId: channelId);
                    },
                    onTap: () => _navigateToProjection(projection),
                    onLongPress: () =>
                        _showActionSheet(context, projection, channelId),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToProjection(ConversationProjection projection) {
    if (projection.threadRouteTarget != null) {
      context.push(projection.threadRouteTarget!.toLocation());
    } else if (projection.channelScopeId != null) {
      final sid = projection.channelScopeId!.serverId.value;
      final cid = projection.channelScopeId!.value;
      context.push('/servers/$sid/channels/$cid');
    } else if (projection.dmScopeId != null) {
      final sid = projection.dmScopeId!.serverId.value;
      final dmId = projection.dmScopeId!.value;
      context.push('/servers/$sid/dms/$dmId');
    }
  }

  Future<void> _showActionSheet(
    BuildContext context,
    ConversationProjection projection,
    String channelId,
  ) async {
    final actions = <ListActionItem>[
      if (projection.unreadCount > 0)
        const ListActionItem(
          key: 'inbox-action-mark-read',
          label: 'Mark Read',
          icon: Icons.mark_email_read,
        ),
      const ListActionItem(
        key: 'inbox-action-mark-done',
        label: 'Done',
        icon: Icons.done,
      ),
    ];

    final result = await showListActionSheet(
      context: context,
      actions: actions,
      title: projection.title,
    );

    switch (result) {
      case 'inbox-action-mark-read':
        ref.read(inboxStoreProvider.notifier).markRead(channelId: channelId);
      case 'inbox-action-mark-done':
        ref.read(inboxStoreProvider.notifier).markDone(channelId: channelId);
    }
  }

  void _showRefreshFailedSnackBar() {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.refreshFailedSnackbar),
        action: SnackBarAction(
          label: l10n.refreshFailedRetry,
          onPressed: () => ref.read(inboxStoreProvider.notifier).refresh(),
        ),
      ));
  }
}

// ---------------------------------------------------------------------------
// Swipeable inbox item — bidirectional swipe
// ---------------------------------------------------------------------------

class _SwipeableInboxItem extends StatefulWidget {
  const _SwipeableInboxItem({
    super.key,
    required this.channelId,
    required this.projection,
    required this.isMentioned,
    required this.onMarkRead,
    required this.onMarkDone,
    required this.onTap,
    required this.onLongPress,
  });

  final String channelId;
  final ConversationProjection projection;
  final bool isMentioned;
  final VoidCallback onMarkRead;
  final VoidCallback onMarkDone;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_SwipeableInboxItem> createState() => _SwipeableInboxItemState();
}

class _SwipeableInboxItemState extends State<_SwipeableInboxItem> {
  bool _hapticFired = false;
  double? _dragStartX;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (_) => _resetDrag(),
      onPointerCancel: (_) => _resetDrag(),
      child: Dismissible(
        key: ValueKey('swipe-action-${widget.channelId}'),
        direction: DismissDirection.horizontal,
        dismissThresholds: const {
          DismissDirection.endToStart: 0.25,
          DismissDirection.startToEnd: 0.25,
        },
        // Right swipe background (startToEnd): mark done — green
        background: _swipeBackground(
          alignment: Alignment.centerLeft,
          color: colors.success,
          icon: Icons.done,
          label: 'Done',
        ),
        // Left swipe background (endToStart): mark read — blue
        secondaryBackground: _swipeBackground(
          alignment: Alignment.centerRight,
          color: colors.primary,
          icon: Icons.mark_email_read,
          label: 'Read',
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // Left swipe → mark read (stays in list)
            widget.onMarkRead();
            return false;
          } else {
            // Right swipe → mark done (dismisses)
            widget.onMarkDone();
            return true;
          }
        },
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          behavior: HitTestBehavior.opaque,
          child: InboxItemTile(
            projection: widget.projection,
            isMentioned: widget.isMentioned,
            channelId: widget.channelId,
            onTap: widget.onTap,
          ),
        ),
      ),
    );
  }

  Widget _swipeBackground({
    required AlignmentGeometry alignment,
    required Color color,
    required IconData icon,
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

  void _onPointerDown(PointerDownEvent event) {
    _dragStartX = event.position.dx;
    _hapticFired = false;
  }

  void _resetDrag() {
    _dragStartX = null;
    _hapticFired = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_hapticFired || _dragStartX == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final width = renderBox.size.width;
    final dragDelta = (_dragStartX! - event.position.dx).abs();

    if (dragDelta > width * 0.15) {
      _hapticFired = true;
      HapticFeedback.mediumImpact();
    }
  }
}

// ---------------------------------------------------------------------------
// Filter tabs (3-tab: Unread | @Mentions | All)
// ---------------------------------------------------------------------------

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
            key: const ValueKey('inbox-filter-unread'),
            label: 'Unread',
            isSelected: currentFilter == InboxFilter.unread,
            colors: colors,
            onTap: () => onFilterChanged(InboxFilter.unread),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterTab(
            key: const ValueKey('inbox-filter-mentions'),
            label: '@Mentions',
            isSelected: currentFilter == InboxFilter.mentions,
            colors: colors,
            onTap: () => onFilterChanged(InboxFilter.mentions),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterTab(
            key: const ValueKey('inbox-filter-all'),
            label: 'All',
            isSelected: currentFilter == InboxFilter.all,
            colors: colors,
            onTap: () => onFilterChanged(InboxFilter.all),
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
