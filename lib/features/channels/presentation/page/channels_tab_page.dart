import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
import 'package:slock_app/app/widgets/snackbar_utils.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/channels/presentation/page/create_channel_page.dart';
import 'package:slock_app/features/channels/presentation/page/browse_channels_page.dart';
import 'package:slock_app/features/channels/presentation/widgets/channel_management_dialogs.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/channel_sort_preference.dart';
import 'package:slock_app/features/home/application/conversation_swipe_preference.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/conversation_swipe_wrapper.dart';
import 'package:slock_app/features/home/presentation/widgets/home_channel_row.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

/// Channels tab — extracts the channel list from [HomePage].
///
/// Reuses [HomeListStore] for data and [HomeChannelRow] for rendering.
/// Adds unread-first sorting and local search filtering.
class ChannelsTabPage extends ConsumerStatefulWidget {
  const ChannelsTabPage({super.key});

  /// Number of times the filter memoization cache was recomputed across
  /// all instances. Exposed for testing to verify the memoization is
  /// load-bearing (counter should NOT increment on unrelated rebuilds).
  @visibleForTesting
  static int filterRecomputeCount = 0;

  /// Number of times the pinnedIds Set was recomputed across all instances.
  /// Exposed for testing to verify the memoization is load-bearing.
  @visibleForTesting
  static int pinnedIdsRecomputeCount = 0;

  @override
  ConsumerState<ChannelsTabPage> createState() => _ChannelsTabPageState();
}

class _ChannelsTabPageState extends ConsumerState<ChannelsTabPage> {
  // Hoisted BorderRadius for search field (Scan #49).
  static final _kSearchBorderRadius =
      BorderRadius.circular(AppSpacing.radiusMd);

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // PERF-819: Memoize filtered list — only recompute when search query or
  // sorted list identity changes, not on unrelated rebuilds (e.g. unread
  // count updates).
  List<HomeChannelSummary>? _cachedSorted;
  String _cachedSearchQuery = '';
  List<HomeChannelSummary>? _cachedDisplayList;

  // PERF-830: Memoize pinnedIds — only recompute when pinnedChannels identity
  // changes, not on every rebuild.
  List<HomeChannelSummary>? _cachedPinnedChannels;
  Set<String>? _cachedPinnedIds;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _searchQuery.isNotEmpty) return;
    final position = _scrollController.position;
    if (position.extentAfter > 320) return;
    final state = ref.read(homeListStoreProvider);
    if (!state.hasMoreChannels || state.isLoadingMoreChannels) return;
    ref.read(homeListStoreProvider.notifier).loadMoreChannels();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      homeListStoreProvider.select(
        (s) => (
          status: s.status,
          failure: s.failure,
          pinnedChannels: s.pinnedChannels,
          channels: s.channels,
          hasMoreChannels: s.hasMoreChannels,
          isLoadingMoreChannels: s.isLoadingMoreChannels,
        ),
      ),
    );
    // INV-NET-DEGRADE-2: surface refresh failure via snackbar only when a
    // refresh completes with failure — not on mutation errors.
    ref.listen(
      homeListStoreProvider.select((s) => s.isRefreshing),
      (prev, next) {
        if (prev == true && next == false) {
          final s = ref.read(homeListStoreProvider);
          if (s.failure != null && s.status == HomeListStatus.success) {
            _showRefreshFailedSnackBar();
          }
        }
      },
    );
    final homeStore = ref.read(homeListStoreProvider.notifier);
    // INV-TAB-UNREAD-SELECT-1: Only consume channelUnreadCounts — DM unread
    // changes must NOT rebuild the channels tab.
    final channelUnreadCounts = ref.watch(
      unreadSourceProjectionProvider.select((s) => s.channelUnreadCounts),
    );
    final channelUnreadTotal =
        channelUnreadCounts.values.fold(0, (sum, c) => sum + c);
    // INV-SELECT-CHANNELS-1: Only isBusy consumed — other management state
    // fields (e.g. operationResult) don't require tab rebuild.
    final isBusy = ref.watch(
      channelManagementStoreProvider.select((s) => s.isBusy),
    );
    final sortPreference = ref.watch(channelSortPreferenceProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.channelsTabTitle),
        actions: [
          IconButton(
            key: const ValueKey('channels-sort-toggle'),
            icon: Icon(
              sortPreference == ChannelSortPreference.recentActivity
                  ? Icons.sort_by_alpha
                  : Icons.access_time,
            ),
            tooltip: sortPreference == ChannelSortPreference.recentActivity
                ? l10n.channelsSortAlphabetical
                : l10n.channelsSortRecent,
            onPressed: () {
              final notifier = ref.read(channelSortPreferenceProvider.notifier);
              notifier.setSortPreference(
                sortPreference == ChannelSortPreference.recentActivity
                    ? ChannelSortPreference.alphabetical
                    : ChannelSortPreference.recentActivity,
              );
            },
          ),
          if (state.status == HomeListStatus.success && channelUnreadTotal > 0)
            IconButton(
              key: const ValueKey('channels-tab-mark-all-read'),
              icon: const Icon(Icons.done_all),
              tooltip: l10n.channelsMarkAllRead,
              onPressed: () {
                ref.read(inboxStoreProvider.notifier).markAllRead();
              },
            ),
          IconButton(
            key: const ValueKey('channels-tab-browse-button'),
            icon: const Icon(Icons.explore),
            tooltip: l10n.channelsBrowseTooltip,
            onPressed: _showBrowseChannelsPage,
          ),
          IconButton(
            key: const ValueKey('channels-tab-create-button'),
            icon: const Icon(Icons.add),
            tooltip: l10n.homeCreateChannelTooltip,
            onPressed: _showCreateChannelDialog,
          ),
        ],
      ),
      body: switch (state.status) {
        HomeListStatus.noActiveServer => _ChannelsNoServerState(
            message: l10n.channelsTabEmpty,
          ),
        HomeListStatus.initial || HomeListStatus.loading => ListView(
            key: const ValueKey('channels-skeleton'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.sm,
            ),
            children: const [
              SkeletonListItem(key: ValueKey('channels-skeleton-item-0')),
              SkeletonListItem(key: ValueKey('channels-skeleton-item-1')),
              SkeletonListItem(key: ValueKey('channels-skeleton-item-2')),
              SkeletonListItem(key: ValueKey('channels-skeleton-item-3')),
              SkeletonListItem(key: ValueKey('channels-skeleton-item-4')),
            ],
          ),
        HomeListStatus.failure => _ChannelsErrorState(
            message: state.failure?.userMessage(l10n) ?? l10n.errorUnknown,
            onRetry: homeStore.retry,
          ),
        HomeListStatus.success => RefreshIndicator(
            key: const ValueKey('channels-tab-refresh'),
            onRefresh: homeStore.refresh,
            child: _buildChannelList(
              pinnedChannels: state.pinnedChannels,
              channels: state.channels,
              hasMoreChannels: state.hasMoreChannels,
              isLoadingMoreChannels: state.isLoadingMoreChannels,
              homeStore: homeStore,
              channelUnreadCounts: channelUnreadCounts,
              managementIsBusy: isBusy,
              l10n: l10n,
            ),
          ),
      },
    );
  }

  Widget _buildChannelList({
    required List<HomeChannelSummary> pinnedChannels,
    required List<HomeChannelSummary> channels,
    required bool hasMoreChannels,
    required bool isLoadingMoreChannels,
    required HomeListStore homeStore,
    required Map<ChannelScopeId, int> channelUnreadCounts,
    required bool managementIsBusy,
    required AppLocalizations l10n,
  }) {
    final colors = Theme.of(context).extension<AppColors>()!;

    // INV-TAB-SORT-CACHE-1: Use memoized provider — sort only re-runs when
    // the channel list or sort preference changes, NOT on unread count updates.
    final sorted = ref.watch(sortedChannelListProvider);

    // PERF-819: Memoized filter — skip recomputation when inputs unchanged.
    if (!identical(sorted, _cachedSorted) ||
        _searchQuery != _cachedSearchQuery) {
      _cachedSorted = sorted;
      _cachedSearchQuery = _searchQuery;
      _cachedDisplayList = _searchQuery.isEmpty
          ? sorted
          : () {
              final queryLower = _searchQuery.toLowerCase();
              return sorted
                  .where((c) => c.name.toLowerCase().contains(queryLower))
                  .toList();
            }();
      ChannelsTabPage.filterRecomputeCount++;
    }
    final displayList = _cachedDisplayList!;

    // PERF-830: Memoize pinnedIds — only recompute when list identity changes.
    if (!identical(pinnedChannels, _cachedPinnedChannels)) {
      _cachedPinnedChannels = pinnedChannels;
      _cachedPinnedIds = pinnedChannels.map((c) => c.scopeId.value).toSet();
      ChannelsTabPage.pinnedIdsRecomputeCount++;
    }
    final pinnedIds = _cachedPinnedIds!;

    if (displayList.isEmpty && _searchQuery.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSearchField(l10n, colors),
          Padding(
            key: const ValueKey('channels-tab-empty'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.lg,
            ),
            child: Center(
              child: Text(
                l10n.channelsTabEmpty,
                style: AppTypography.body.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // INV-CHANNELS-MUTED-HOIST-1: Hoist mutedIds watch above the builder
    // so it is registered once (not N times per row).
    final mutedIds = ref.watch(channelMutedIdsProvider);

    if (_searchQuery.isNotEmpty) {
      return ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: displayList.length + 1 + (displayList.isEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSearchField(l10n, colors);
          }
          if (displayList.isEmpty && index == 1) {
            return Padding(
              key: const ValueKey('channels-tab-search-empty'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal,
                vertical: AppSpacing.lg,
              ),
              child: Center(
                child: Text(
                  l10n.channelsTabEmpty,
                  style: AppTypography.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            );
          }
          final dataIndex = index - 1;
          if (dataIndex < 0 || dataIndex >= displayList.length) {
            return const SizedBox.shrink();
          }
          final channel = displayList[dataIndex];
          return _buildChannelRow(
            channel: channel,
            isPinned: pinnedIds.contains(channel.scopeId.value),
            homeStore: homeStore,
            channelUnreadCounts: channelUnreadCounts,
            mutedIds: mutedIds,
            managementIsBusy: managementIsBusy,
          );
        },
      );
    }

    return ReorderableListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      key: const ValueKey('channels-tab-reorder-list'),
      buildDefaultDragHandles: false,
      scrollController: _scrollController,
      header: _buildSearchField(l10n, colors),
      footer: isLoadingMoreChannels
          ? const _ChannelsLoadMoreIndicator(
              key: ValueKey('channels-load-more-indicator'),
            )
          : hasMoreChannels
              ? const SizedBox(key: ValueKey('channels-load-more-sentinel'))
              : null,
      itemCount: displayList.length,
      onReorder: (oldIndex, newIndex) {
        _handleChannelReorder(
          oldIndex: oldIndex,
          newIndex: newIndex,
          displayList: displayList,
          pinnedIds: pinnedIds,
          homeStore: homeStore,
        );
      },
      itemBuilder: (context, index) {
        final channel = displayList[index];
        final isPinned = pinnedIds.contains(channel.scopeId.value);
        return KeyedSubtree(
          key: ValueKey('channels-reorder-${channel.scopeId.routeParam}'),
          child: _buildChannelRow(
            channel: channel,
            isPinned: isPinned,
            reorderIndex: isPinned ? null : index,
            homeStore: homeStore,
            channelUnreadCounts: channelUnreadCounts,
            mutedIds: mutedIds,
            managementIsBusy: managementIsBusy,
          ),
        );
      },
    );
  }

  Future<void> _handleChannelReorder({
    required int oldIndex,
    required int newIndex,
    required List<HomeChannelSummary> displayList,
    required Set<String> pinnedIds,
    required HomeListStore homeStore,
  }) async {
    if (oldIndex < 0 || oldIndex >= displayList.length) return;
    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (adjustedNewIndex < 0 || adjustedNewIndex >= displayList.length) {
      return;
    }

    final reordered = List<HomeChannelSummary>.of(displayList);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(adjustedNewIndex, moved);
    final reorderedVisibleIds = reordered
        .where((channel) => !pinnedIds.contains(channel.scopeId.value))
        .map((channel) => channel.scopeId.value)
        .toList(growable: false);

    final previousPreference = ref.read(channelSortPreferenceProvider);
    ref
        .read(channelSortPreferenceProvider.notifier)
        .setSortPreference(ChannelSortPreference.custom);
    final persisted = await homeStore.reorderChannels(
      moved.scopeId.serverId,
      reorderedVisibleIds,
    );
    if (!persisted && mounted) {
      ref
          .read(channelSortPreferenceProvider.notifier)
          .setSortPreference(previousPreference);
    }
  }

  Widget _buildSearchField(AppLocalizations l10n, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: TextField(
        key: const ValueKey('channels-tab-search'),
        controller: _searchController,
        decoration: InputDecoration(
          hintText: l10n.channelsTabSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? Tooltip(
                  message: l10n.channelsClearSearch,
                  child: IconButton(
                    key: const ValueKey('search-clear-button'),
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                )
              : null,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: _kSearchBorderRadius,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildChannelRow({
    required HomeChannelSummary channel,
    required bool isPinned,
    int? reorderIndex,
    required HomeListStore homeStore,
    required Map<ChannelScopeId, int> channelUnreadCounts,
    required Set<String> mutedIds,
    required bool managementIsBusy,
  }) {
    final unreadCount = channelUnreadCounts[channel.scopeId] ?? 0;

    // Per-channel mute indicator: uses composite key to match the
    // in-memory muted IDs set (which is serverId-scoped).
    // INV-CHANNELS-MUTED-HOIST-1: mutedIds passed in from hoisted watch.
    final isMuted = mutedIds.contains(
      ChannelNotificationPreferenceRepository.compositeKey(
        channel.scopeId.serverId.value,
        channel.scopeId.value,
      ),
    );

    final swipePreference = ref.watch(conversationSwipePreferenceProvider);

    // Move actions are suppressed in this tab because the unread-first
    // merged view does not match the persisted sidebar order that
    // moveChannel() / movePinnedConversation() operate on.
    return ConversationSwipeWrapper(
      itemKey: channel.scopeId.routeParam,
      actions: ConversationSwipeActions(
        left: swipePreference.left,
        right: swipePreference.right,
      ),
      isPinned: isPinned,
      isMuted: isMuted,
      callbacks: ConversationSwipeCallbacks(
        onArchive:
            channel.isArchived ? null : () => _archiveChannelFromSwipe(channel),
        onTogglePin: () => isPinned
            ? homeStore.unpinChannel(channel.scopeId)
            : homeStore.pinChannel(channel.scopeId),
        onToggleMute: () => _toggleChannelMute(channel, isMuted: isMuted),
      ),
      child: HomeChannelRow(
        key: ValueKey('channels-tab-${channel.scopeId.routeParam}'),
        channel: channel,
        unreadCount: unreadCount,
        isPinned: isPinned,
        isMuted: isMuted,
        isMutating: managementIsBusy,
        onTap: () {
          context.push(homeStore.channelRoutePath(channel.scopeId));
          // Deferred mark-read: brief delay before clearing unread
          // so the user sees the conversation before the count drops.
          Future.delayed(const Duration(seconds: 1), () {
            if (!mounted) return;
            ref.read(markChannelReadUseCaseProvider)(channel.scopeId);
          });
        },
        onEdit: () => _showEditChannelDialog(channel),
        onDelete: () => _showDeleteChannelDialog(channel),
        onLeave: () => _showLeaveChannelDialog(channel),
        onArchive: channel.isArchived ? null : () => _archiveChannel(channel),
        onUnarchive:
            channel.isArchived ? () => _unarchiveChannel(channel) : null,
        onTogglePin: () => isPinned
            ? homeStore.unpinChannel(channel.scopeId)
            : homeStore.pinChannel(channel.scopeId),
        onMarkAsUnread:
            unreadCount == 0 ? () => _markChannelUnread(channel) : null,
        reorderHandle: reorderIndex == null
            ? null
            : ReorderableDragStartListener(
                key: ValueKey(
                  'channels-tab-drag-${channel.scopeId.routeParam}',
                ),
                index: reorderIndex,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle),
                ),
              ),
      ),
    );
  }

  Future<void> _markChannelUnread(HomeChannelSummary channel) async {
    try {
      await ref.read(inboxStoreProvider.notifier).markAsUnread(
            channelId: channel.scopeId.value,
            kind: InboxItemKind.channel,
            channelName: channel.name,
          );
      if (!mounted) return;
      showAppSnackBar(context, context.l10n.channelsMarkedUnread);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        failure.userMessage(context.l10n),
      );
    }
  }

  Future<void> _showBrowseChannelsPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const BrowseChannelsPage(),
      ),
    );
  }

  Future<void> _showCreateChannelDialog() async {
    final l10n = context.l10n;
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;
    final pageContext = context;

    final channelId = await Navigator.of(pageContext).push<String>(
      MaterialPageRoute(
        builder: (_) => const CreateChannelPage(),
      ),
    );

    if (channelId != null && mounted && pageContext.mounted) {
      showAppSnackBar(context, l10n.homeChannelCreated);
      // Push instead of go to preserve the channels tab in the back stack.
      // context.go() replaces the entire stack, making back exit the app.
      pageContext.push(
        '/servers/${serverId.routeParam}/channels/$channelId',
      );
    }
  }

  Future<void> _showEditChannelDialog(
    HomeChannelSummary channel,
  ) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(channelManagementStoreProvider);
            final store = ref.read(channelManagementStoreProvider.notifier);
            return EditChannelDialog(
              currentName: channel.name,
              currentDescription: channel.description,
              currentIsPrivate: channel.isPrivate,
              isSubmitting: state.isRunning(
                ChannelManagementAction.edit,
                channelId: channel.scopeId.value,
              ),
              onCancel: () => Navigator.of(dialogContext).pop(),
              onSave: (result) async {
                try {
                  await store.updateChannel(
                    channel.scopeId,
                    name: result.name != channel.name ? result.name : null,
                    description:
                        result.description != (channel.description ?? '')
                            ? result.description
                            : null,
                    isPrivate: result.isPrivate != channel.isPrivate
                        ? result.isPrivate
                        : null,
                  );
                  if (!context.mounted) return;
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  showAppSnackBar(context, l10n.homeChannelUpdated);
                } on AppFailure catch (failure) {
                  if (!context.mounted) return;
                  showAppSnackBar(
                    context,
                    failure.userMessage(l10n),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteChannelDialog(
    HomeChannelSummary channel,
  ) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(channelManagementStoreProvider);
            final store = ref.read(channelManagementStoreProvider.notifier);
            return ConfirmChannelActionDialog(
              dialogKey: const ValueKey('delete-channel-dialog'),
              title: l10n.homeDeleteChannelTitle,
              message: l10n.homeDeleteChannelMessage(channel.name),
              confirmLabel: l10n.homeDeleteChannelConfirm,
              isSubmitting: state.isRunning(
                ChannelManagementAction.delete,
                channelId: channel.scopeId.value,
              ),
              onCancel: () => Navigator.of(dialogContext).pop(),
              onConfirm: () async {
                try {
                  await store.deleteChannel(channel.scopeId);
                  if (!context.mounted) return;
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  showAppSnackBar(context, l10n.homeChannelDeleted);
                } on AppFailure catch (failure) {
                  if (!context.mounted) return;
                  showAppSnackBar(
                    context,
                    failure.userMessage(l10n),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showLeaveChannelDialog(
    HomeChannelSummary channel,
  ) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(channelManagementStoreProvider);
            final store = ref.read(channelManagementStoreProvider.notifier);
            return ConfirmChannelActionDialog(
              dialogKey: const ValueKey('leave-channel-dialog'),
              title: l10n.homeLeaveChannelTitle,
              message: l10n.homeLeaveChannelMessage(channel.name),
              confirmLabel: l10n.homeLeaveChannelConfirm,
              isSubmitting: state.isRunning(
                ChannelManagementAction.leave,
                channelId: channel.scopeId.value,
              ),
              onCancel: () => Navigator.of(dialogContext).pop(),
              onConfirm: () async {
                try {
                  await store.leaveChannel(channel.scopeId);
                  if (!context.mounted) return;
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  showAppSnackBar(context, l10n.homeChannelLeft);
                } on AppFailure catch (failure) {
                  if (!context.mounted) return;
                  showAppSnackBar(
                    context,
                    failure.userMessage(l10n),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _archiveChannelFromSwipe(HomeChannelSummary channel) async {
    final l10n = context.l10n;
    try {
      final archived = await ref
          .read(channelManagementStoreProvider.notifier)
          .archiveChannel(channel.scopeId);
      if (!archived || !mounted) return;
      showAppSnackBarWithAction(
        context,
        l10n.conversationSwipeArchived(channel.name),
        actionLabel: l10n.undoAction,
        onAction: () {
          ref
              .read(channelManagementStoreProvider.notifier)
              .unarchiveChannel(channel.scopeId);
        },
      );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(context, failure.userMessage(l10n), isError: true);
    }
  }

  Future<void> _toggleChannelMute(
    HomeChannelSummary channel, {
    required bool isMuted,
  }) async {
    final repo = ref.read(channelNotificationPreferenceRepositoryProvider);
    await repo.setChannelMuted(
      channel.scopeId.serverId.value,
      channel.scopeId.value,
      muted: !isMuted,
    );
    final key = ChannelNotificationPreferenceRepository.compositeKey(
      channel.scopeId.serverId.value,
      channel.scopeId.value,
    );
    final mutedIds = ref.read(channelMutedIdsProvider);
    ref.read(channelMutedIdsProvider.notifier).state = !isMuted
        ? {...mutedIds, key}
        : mutedIds.where((id) => id != key).toSet();
  }

  Future<void> _archiveChannel(HomeChannelSummary channel) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(channelManagementStoreProvider);
            final store = ref.read(channelManagementStoreProvider.notifier);
            return ConfirmChannelActionDialog(
              dialogKey: const ValueKey('archive-channel-dialog'),
              title: l10n.channelArchiveConfirmTitle,
              message: l10n.channelArchiveConfirmBody,
              confirmLabel: l10n.channelActionArchive,
              isSubmitting: state.isRunning(
                ChannelManagementAction.archive,
                channelId: channel.scopeId.value,
              ),
              onCancel: () => Navigator.of(dialogContext).pop(),
              onConfirm: () async {
                try {
                  await store.archiveChannel(channel.scopeId);
                  if (!context.mounted) return;
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } on AppFailure catch (failure) {
                  if (!context.mounted) return;
                  showAppSnackBar(
                    context,
                    failure.userMessage(l10n),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _unarchiveChannel(HomeChannelSummary channel) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(channelManagementStoreProvider);
            final store = ref.read(channelManagementStoreProvider.notifier);
            return ConfirmChannelActionDialog(
              dialogKey: const ValueKey('unarchive-channel-dialog'),
              title: l10n.channelUnarchiveConfirmTitle,
              message: l10n.channelUnarchiveConfirmBody,
              confirmLabel: l10n.channelActionUnarchive,
              isSubmitting: state.isRunning(
                ChannelManagementAction.unarchive,
                channelId: channel.scopeId.value,
              ),
              onCancel: () => Navigator.of(dialogContext).pop(),
              onConfirm: () async {
                try {
                  await store.unarchiveChannel(channel.scopeId);
                  if (!context.mounted) return;
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } on AppFailure catch (failure) {
                  if (!context.mounted) return;
                  showAppSnackBar(
                    context,
                    failure.userMessage(l10n),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  void _showRefreshFailedSnackBar() {
    final l10n = context.l10n;
    showAppSnackBarWithAction(
      context,
      l10n.refreshFailedSnackbar,
      actionLabel: l10n.refreshFailedRetry,
      onAction: () => ref.read(homeListStoreProvider.notifier).refresh(),
    );
  }
}

class _ChannelsNoServerState extends StatelessWidget {
  const _ChannelsNoServerState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Text(
        message,
        style: AppTypography.body.copyWith(
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

class _ChannelsErrorState extends StatelessWidget {
  const _ChannelsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.homeRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelsLoadMoreIndicator extends StatelessWidget {
  const _ChannelsLoadMoreIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
