import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/connection_status_banner.dart';
import 'package:slock_app/app/widgets/list_action_sheet.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
import 'package:slock_app/app/widgets/snackbar_utils.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/app/widgets/empty_state_widget.dart';
import 'package:slock_app/features/inbox/presentation/widgets/inbox_item_tile.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// #509: Inbox page redesign — Z2 mockup.
//
// 3-tab filter (Unread | @Mentions | All), redesigned InboxItemTile,
// bidirectional swipe (left=mark read, right=done), EmptyStateWidget.
// ---------------------------------------------------------------------------

/// Record type for the body's narrowed .select() watch.
typedef _InboxBodyState = ({
  InboxStatus status,
  List<InboxItem> items,
  bool isRefreshing,
  bool hasMore,
  AppFailure? failure,
});

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
    // Always reset to unread filter when InboxPage opens.
    // INV-FILTER-RACE-1: Home may pre-load inbox with filter=all
    // (status != initial), so the old guard (status == initial)
    // would skip setFilter → inbox stuck on All.
    // INV-FILTER-RACE-2: Re-opening after manual filter switch
    // must also reset to unread.
    Future.microtask(
      () => ref.read(inboxStoreProvider.notifier).setFilter(InboxFilter.unread),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    // INV-INBOX-SELECT-SPLIT-1: AppBar only needs status + totalUnreadCount.
    final appBarState = ref.watch(
      inboxStoreProvider.select(
        (s) => (status: s.status, totalUnreadCount: s.totalUnreadCount),
      ),
    );

    // INV-INBOX-SELECT-SPLIT-2: Body needs status + items + isRefreshing +
    // hasMore + failure. Filter and totalUnreadCount changes do NOT trigger
    // body rebuild.
    final bodyState = ref.watch(
      inboxStoreProvider.select(
        (s) => (
          status: s.status,
          items: s.items,
          isRefreshing: s.isRefreshing,
          hasMore: s.hasMore,
          failure: s.failure,
        ),
      ),
    );

    // Filter tabs — separate narrow select.
    final filter = ref.watch(
      inboxStoreProvider.select((s) => s.filter),
    );

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
        title: Text(context.l10n.inboxTitle),
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        elevation: 0,
        actions: [
          if (appBarState.status == InboxStatus.success &&
              appBarState.totalUnreadCount > 0)
            IconButton(
              key: const ValueKey('inbox-mark-all-read'),
              icon: const Icon(Icons.done_all),
              tooltip: context.l10n.inboxMarkAllReadTooltip,
              onPressed: () {
                ref.read(inboxStoreProvider.notifier).markAllRead();
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _InboxFilterTabs(
            currentFilter: filter,
            onFilterChanged: (filter) {
              ref.read(inboxStoreProvider.notifier).setFilter(filter);
            },
          ),
        ),
      ),
      body: Column(
        children: [
          const ConnectionStatusBanner(),
          Expanded(child: _buildBody(colors, bodyState)),
        ],
      ),
    );
  }

  Widget _buildBody(AppColors colors, _InboxBodyState inboxState) {
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
              context.l10n.inboxLoadFailed,
              style: AppTypography.body.copyWith(color: colors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => ref.read(inboxStoreProvider.notifier).refresh(),
              child: Text(context.l10n.inboxRetry),
            ),
          ],
        ),
      );
    }

    if (inboxState.items.isEmpty) {
      return EmptyStateWidget(
        key: const ValueKey('inbox-empty'),
        icon: Icons.inbox_outlined,
        title: context.l10n.inboxEmptyTitle,
        subtitle: context.l10n.inboxEmptySubtitle,
      );
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
                    onTap: () {
                      ref
                          .read(inboxStoreProvider.notifier)
                          .markRead(channelId: channelId);
                      _navigateToProjection(projection);
                    },
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
        ListActionItem(
          key: 'inbox-action-mark-read',
          label: context.l10n.inboxActionMarkRead,
          icon: Icons.mark_email_read,
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
    }
  }

  void _showRefreshFailedSnackBar() {
    final l10n = context.l10n;
    showAppSnackBarWithAction(
      context,
      l10n.refreshFailedSnackbar,
      actionLabel: l10n.refreshFailedRetry,
      onAction: () => ref.read(inboxStoreProvider.notifier).refresh(),
    );
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
        direction: DismissDirection.endToStart,
        dismissThresholds: const {
          DismissDirection.endToStart: 0.25,
        },
        // Left swipe background (endToStart): mark read — blue
        background: _swipeBackground(
          alignment: Alignment.centerRight,
          color: colors.primary,
          icon: Icons.mark_email_read,
          label: context.l10n.inboxSwipeLabelRead,
        ),
        confirmDismiss: (_) async {
          widget.onMarkRead();
          return false;
        },
        child: Semantics(
          button: true,
          label: context.l10n.inboxItemSemantics,
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
          Flexible(
            child: _FilterTab(
              key: const ValueKey('inbox-filter-unread'),
              label: context.l10n.inboxFilterUnread,
              isSelected: currentFilter == InboxFilter.unread,
              colors: colors,
              onTap: () => onFilterChanged(InboxFilter.unread),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: _FilterTab(
              key: const ValueKey('inbox-filter-mentions'),
              label: context.l10n.inboxFilterMentions,
              isSelected: currentFilter == InboxFilter.mentions,
              colors: colors,
              onTap: () => onFilterChanged(InboxFilter.mentions),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: _FilterTab(
              key: const ValueKey('inbox-filter-dms'),
              label: context.l10n.inboxFilterDms,
              isSelected: currentFilter == InboxFilter.dms,
              colors: colors,
              onTap: () => onFilterChanged(InboxFilter.dms),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: _FilterTab(
              key: const ValueKey('inbox-filter-all'),
              label: context.l10n.inboxFilterAll,
              isSelected: currentFilter == InboxFilter.all,
              colors: colors,
              onTap: () => onFilterChanged(InboxFilter.all),
            ),
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
    return Semantics(
      button: true,
      label: context.l10n.inboxFilterTabSemantics(label),
      child: GestureDetector(
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
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: AppTypography.label.copyWith(
              color: isSelected ? colors.primary : colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
