import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/channels/presentation/widgets/channel_management_dialogs.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_channel_row.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_state.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeListStoreProvider);
    final homeStore = ref.read(homeListStoreProvider.notifier);
    final unreadState = ref.watch(channelUnreadStoreProvider);
    final unreadStore = ref.read(channelUnreadStoreProvider.notifier);
    final managementState = ref.watch(channelManagementStoreProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.channelsTabTitle),
        actions: [
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
        HomeListStatus.initial ||
        HomeListStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        HomeListStatus.failure => _ChannelsErrorState(
            message: state.failure?.message ?? l10n.homeLoadFailedFallback,
            onRetry: homeStore.retry,
          ),
        HomeListStatus.success => RefreshIndicator(
            key: const ValueKey('channels-tab-refresh'),
            onRefresh: homeStore.load,
            child: _buildChannelList(
              state: state,
              homeStore: homeStore,
              unreadState: unreadState,
              unreadStore: unreadStore,
              managementState: managementState,
              l10n: l10n,
            ),
          ),
      },
    );
  }

  Widget _buildChannelList({
    required HomeListState state,
    required HomeListStore homeStore,
    required ChannelUnreadState unreadState,
    required ChannelUnreadStore unreadStore,
    required ChannelManagementState managementState,
    required AppLocalizations l10n,
  }) {
    final colors = Theme.of(context).extension<AppColors>()!;

    // Combine pinned + unpinned channels.
    final allChannels = [
      ...state.pinnedChannels,
      ...state.channels,
    ];

    // Apply search filter.
    final filtered = _searchQuery.isEmpty
        ? allChannels
        : allChannels
            .where(
              (c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

    // Sort unread-first (preserve relative order within each group).
    final unread = <HomeChannelSummary>[];
    final read = <HomeChannelSummary>[];
    for (final channel in filtered) {
      if (unreadState.channelUnreadCount(channel.scopeId) > 0) {
        unread.add(channel);
      } else {
        read.add(channel);
      }
    }
    final sorted = [...unread, ...read];

    final pinnedIds = state.pinnedChannels.map((c) => c.scopeId.value).toSet();

    if (sorted.isEmpty && _searchQuery.isEmpty) {
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
        if (sorted.isEmpty && _searchQuery.isNotEmpty)
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
        for (var i = 0; i < sorted.length; i++)
          _buildChannelRow(
            channel: sorted[i],
            isPinned: pinnedIds.contains(sorted[i].scopeId.value),
            homeStore: homeStore,
            unreadState: unreadState,
            unreadStore: unreadStore,
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
        decoration: InputDecoration(
          hintText: l10n.channelsTabSearchHint,
          prefixIcon: const Icon(Icons.search),
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
    required ChannelUnreadState unreadState,
    required ChannelUnreadStore unreadStore,
    required ChannelManagementState managementState,
  }) {
    // Move actions are suppressed in this tab because the unread-first
    // merged view does not match the persisted sidebar order that
    // moveChannel() / movePinnedConversation() operate on.
    return HomeChannelRow(
      key: ValueKey('channels-tab-${channel.scopeId.routeParam}'),
      channel: channel,
      unreadCount: unreadState.channelUnreadCount(channel.scopeId),
      isPinned: isPinned,
      isMutating: managementState.isBusy,
      onTap: () {
        ref.read(markChannelReadUseCaseProvider)(channel.scopeId);
        context.push(homeStore.channelRoutePath(channel.scopeId));
      },
      onEdit: () => _showEditChannelDialog(channel),
      onDelete: () => _showDeleteChannelDialog(channel),
      onLeave: () => _showLeaveChannelDialog(channel),
      onTogglePin: () => isPinned
          ? homeStore.unpinChannel(channel.scopeId)
          : homeStore.pinChannel(channel.scopeId),
    );
  }

  Future<void> _showCreateChannelDialog() async {
    final l10n = context.l10n;
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;
    final pageContext = context;

    await showDialog<void>(
      context: pageContext,
      builder: (dialogContext) {
        return Consumer(
          builder: (_, ref, __) {
            final state = ref.watch(channelManagementStoreProvider);
            final store = ref.read(channelManagementStoreProvider.notifier);
            return CreateChannelDialog(
              isSubmitting: state.isRunning(ChannelManagementAction.create),
              onCancel: () => Navigator.of(dialogContext).pop(),
              onCreate: (name) async {
                try {
                  final channelId = await store.createChannel(name);
                  if (!mounted || !pageContext.mounted) return;
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  _showSnackBar(l10n.homeChannelCreated);
                  if (channelId != null) {
                    pageContext.go(
                      '/servers/${serverId.routeParam}/channels/$channelId',
                    );
                  }
                } on AppFailure catch (failure) {
                  if (!mounted) return;
                  _showSnackBar(
                    failure.message ?? l10n.homeChannelCreateFailed,
                  );
                }
              },
            );
          },
        );
      },
    );
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
