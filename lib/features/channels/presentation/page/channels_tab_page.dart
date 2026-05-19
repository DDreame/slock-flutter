import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
import 'package:slock_app/app/widgets/swipe_to_mark_read.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/channels/presentation/page/create_channel_page.dart';
import 'package:slock_app/features/channels/presentation/widgets/channel_management_dialogs.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/channel_sort_preference.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_channel_row.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

/// Channels tab — extracts the channel list from [HomePage].
///
/// Reuses [HomeListStore] for data and [HomeChannelRow] for rendering.
/// Adds unread-first sorting and local search filtering.
class ChannelsTabPage extends ConsumerStatefulWidget {
  const ChannelsTabPage({super.key});

  @override
  ConsumerState<ChannelsTabPage> createState() => _ChannelsTabPageState();
}

class _ChannelsTabPageState extends ConsumerState<ChannelsTabPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final unreadState = ref.watch(unreadSourceProjectionProvider);
    final managementState = ref.watch(channelManagementStoreProvider);
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
                ? 'Sort A-Z'
                : 'Sort by recent',
            onPressed: () {
              final notifier = ref.read(channelSortPreferenceProvider.notifier);
              notifier.setSortPreference(
                sortPreference == ChannelSortPreference.recentActivity
                    ? ChannelSortPreference.alphabetical
                    : ChannelSortPreference.recentActivity,
              );
            },
          ),
          if (state.status == HomeListStatus.success &&
              unreadState.channelUnreadTotal > 0)
            IconButton(
              key: const ValueKey('channels-tab-mark-all-read'),
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all read',
              onPressed: () {
                ref.read(inboxStoreProvider.notifier).markAllRead();
              },
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
            message: state.failure?.message ?? l10n.homeLoadFailedFallback,
            onRetry: homeStore.retry,
          ),
        HomeListStatus.success => RefreshIndicator(
            key: const ValueKey('channels-tab-refresh'),
            onRefresh: homeStore.load,
            child: _buildChannelList(
              pinnedChannels: state.pinnedChannels,
              channels: state.channels,
              homeStore: homeStore,
              unreadState: unreadState,
              managementState: managementState,
              l10n: l10n,
            ),
          ),
      },
    );
  }

  Widget _buildChannelList({
    required List<HomeChannelSummary> pinnedChannels,
    required List<HomeChannelSummary> channels,
    required HomeListStore homeStore,
    required UnreadSourceProjectionState unreadState,
    required ChannelManagementState managementState,
    required AppLocalizations l10n,
  }) {
    final colors = Theme.of(context).extension<AppColors>()!;

    // Combine pinned + unpinned channels.
    final allChannels = [
      ...pinnedChannels,
      ...channels,
    ];

    // Apply sort preference via sortedChannelsProvider.
    final sorted = ref.watch(sortedChannelsProvider(allChannels));

    // Apply search filter.
    final displayList = _searchQuery.isEmpty
        ? sorted
        : () {
            final queryLower = _searchQuery.toLowerCase();
            return sorted
                .where((c) => c.name.toLowerCase().contains(queryLower))
                .toList();
          }();

    final pinnedIds = pinnedChannels.map((c) => c.scopeId.value).toSet();

    if (displayList.isEmpty && _searchQuery.isEmpty) {
      return ListView(
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

    return ListView(
      children: [
        _buildSearchField(l10n, colors),
        if (displayList.isEmpty && _searchQuery.isNotEmpty)
          Padding(
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
          ),
        for (var i = 0; i < displayList.length; i++)
          _buildChannelRow(
            channel: displayList[i],
            isPinned: pinnedIds.contains(displayList[i].scopeId.value),
            homeStore: homeStore,
            unreadState: unreadState,
            managementState: managementState,
          ),
      ],
    );
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
                  message: 'Clear search',
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
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
    required HomeListStore homeStore,
    required UnreadSourceProjectionState unreadState,
    required ChannelManagementState managementState,
  }) {
    final unreadCount = unreadState.channelUnreadCount(channel.scopeId);

    // Per-channel mute indicator: uses composite key to match the
    // in-memory muted IDs set (which is serverId-scoped).
    final mutedIds = ref.watch(channelMutedIdsProvider);
    final isMuted = mutedIds.contains(
      ChannelNotificationPreferenceRepository.compositeKey(
        channel.scopeId.serverId.value,
        channel.scopeId.value,
      ),
    );

    // Move actions are suppressed in this tab because the unread-first
    // merged view does not match the persisted sidebar order that
    // moveChannel() / movePinnedConversation() operate on.
    return SwipeToMarkRead(
      itemKey: channel.scopeId.routeParam,
      enabled: unreadCount > 0,
      onMarkRead: () {
        ref.read(markChannelReadUseCaseProvider)(channel.scopeId);
      },
      child: HomeChannelRow(
        key: ValueKey('channels-tab-${channel.scopeId.routeParam}'),
        channel: channel,
        unreadCount: unreadCount,
        isPinned: isPinned,
        isMuted: isMuted,
        isMutating: managementState.isBusy,
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
        onTogglePin: () => isPinned
            ? homeStore.unpinChannel(channel.scopeId)
            : homeStore.pinChannel(channel.scopeId),
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
      _showSnackBar(l10n.homeChannelCreated);
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
              isSubmitting: state.isRunning(
                ChannelManagementAction.edit,
                channelId: channel.scopeId.value,
              ),
              onCancel: () => Navigator.of(dialogContext).pop(),
              onSave: (name) async {
                try {
                  await store.renameChannel(
                    channel.scopeId,
                    name: name,
                  );
                  if (!mounted) return;
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  _showSnackBar(l10n.homeChannelUpdated);
                } on AppFailure catch (failure) {
                  if (!mounted) return;
                  _showSnackBar(
                    failure.message ?? l10n.homeChannelUpdateFailed,
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
                  if (!mounted) return;
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  _showSnackBar(l10n.homeChannelDeleted);
                } on AppFailure catch (failure) {
                  if (!mounted) return;
                  _showSnackBar(
                    failure.message ?? l10n.homeChannelDeleteFailed,
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
                  if (!mounted) return;
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  _showSnackBar(l10n.homeChannelLeft);
                } on AppFailure catch (failure) {
                  if (!mounted) return;
                  _showSnackBar(
                    failure.message ?? l10n.homeChannelLeaveFailed,
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showRefreshFailedSnackBar() {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.refreshFailedSnackbar),
        action: SnackBarAction(
          label: l10n.refreshFailedRetry,
          onPressed: () => ref.read(homeListStoreProvider.notifier).refresh(),
        ),
      ));
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
