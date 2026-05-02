import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_admin_realtime_binding.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_direct_message_row.dart';
import 'package:slock_app/features/home/presentation/widgets/new_dm_dialog.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_state.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

/// DMs tab — extracts the DM list from [HomePage].
///
/// Reuses [HomeListStore] for data and [HomeDirectMessageRow] for rendering.
/// Adds unread-first sorting, local search filtering, online-status dots,
/// hidden-DM management, and a "new message" action.
class DmsTabPage extends ConsumerStatefulWidget {
  const DmsTabPage({super.key});

  @override
  ConsumerState<DmsTabPage> createState() => _DmsTabPageState();
}

class _DmsTabPageState extends ConsumerState<DmsTabPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // Keep the admin realtime binding alive while this tab is visible,
    // so channel:updated / server:membership-removed events continue
    // flowing even when the user is not on the Home tab.
    ref.watch(homeAdminRealtimeBindingProvider);

    final state = ref.watch(homeListStoreProvider);
    final homeStore = ref.read(homeListStoreProvider.notifier);
    final unreadState = ref.watch(channelUnreadStoreProvider);
    final unreadStore = ref.read(channelUnreadStoreProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dmsTabTitle),
        actions: [
          IconButton(
            key: const ValueKey('dms-tab-create-button'),
            icon: const Icon(Icons.add),
            tooltip: l10n.homeNewMessageTooltip,
            onPressed: _showNewDmDialog,
          ),
        ],
      ),
      body: switch (state.status) {
        HomeListStatus.noActiveServer => _DmsNoServerState(
            message: l10n.dmsTabEmpty,
          ),
        HomeListStatus.initial ||
        HomeListStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        HomeListStatus.failure => _DmsErrorState(
            message: state.failure?.message ?? l10n.homeLoadFailedFallback,
            onRetry: homeStore.retry,
          ),
        HomeListStatus.success => RefreshIndicator(
            key: const ValueKey('dms-tab-refresh'),
            onRefresh: homeStore.load,
            child: _buildDmList(
              state: state,
              homeStore: homeStore,
              unreadState: unreadState,
              unreadStore: unreadStore,
              l10n: l10n,
            ),
          ),
      },
    );
  }

  Widget _buildDmList({
    required HomeListState state,
    required HomeListStore homeStore,
    required ChannelUnreadState unreadState,
    required ChannelUnreadStore unreadStore,
    required AppLocalizations l10n,
  }) {
    final colors = Theme.of(context).extension<AppColors>()!;

    // Build online agent name lookup for status dots.
    final onlineAgentNames = <String>{
      for (final agent in state.agents)
        if (agent.isActive) agent.label,
      for (final agent in state.pinnedAgents)
        if (agent.isActive) agent.label,
    };

    // Combine pinned + unpinned DMs.
    final allDms = [
      ...state.pinnedDirectMessages,
      ...state.directMessages,
    ];

    // Apply search filter.
    final filtered = _searchQuery.isEmpty
        ? allDms
        : allDms
            .where(
              (dm) =>
                  dm.title.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

    // Sort unread-first (preserve relative order within each group).
    final unread = <HomeDirectMessageSummary>[];
    final read = <HomeDirectMessageSummary>[];
    for (final dm in filtered) {
      if (unreadState.dmUnreadCount(dm.scopeId) > 0) {
        unread.add(dm);
      } else {
        read.add(dm);
      }
    }
    final sorted = [...unread, ...read];

    final pinnedIds =
        state.pinnedDirectMessages.map((dm) => dm.scopeId.value).toSet();

    if (sorted.isEmpty && _searchQuery.isEmpty) {
      return ListView(
        children: [
          _buildSearchField(l10n, colors),
          if (state.hiddenDirectMessages.isNotEmpty)
            _buildHiddenDmsTile(
              state: state,
              homeStore: homeStore,
              unreadStore: unreadStore,
              l10n: l10n,
            ),
          Padding(
            key: const ValueKey('dms-tab-empty'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.lg,
            ),
            child: Center(
              child: Text(
                l10n.dmsTabEmpty,
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
            key: const ValueKey('dms-tab-search-empty'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.lg,
            ),
            child: Center(
              child: Text(
                l10n.dmsTabEmpty,
                style: AppTypography.body.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        for (final dm in sorted)
          _buildDmRow(
            dm: dm,
            isPinned: pinnedIds.contains(dm.scopeId.value),
            isOnline: onlineAgentNames.contains(dm.title),
            homeStore: homeStore,
            unreadState: unreadState,
            unreadStore: unreadStore,
          ),
        if (state.hiddenDirectMessages.isNotEmpty && _searchQuery.isEmpty)
          _buildHiddenDmsTile(
            state: state,
            homeStore: homeStore,
            unreadStore: unreadStore,
            l10n: l10n,
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
        key: const ValueKey('dms-tab-search'),
        decoration: InputDecoration(
          hintText: l10n.dmsTabSearchHint,
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

  Widget _buildDmRow({
    required HomeDirectMessageSummary dm,
    required bool isPinned,
    required bool isOnline,
    required HomeListStore homeStore,
    required ChannelUnreadState unreadState,
    required ChannelUnreadStore unreadStore,
  }) {
    // Move actions are suppressed in this tab because the unread-first
    // merged view does not match the persisted sidebar order.
    return HomeDirectMessageRow(
      key: ValueKey('dms-tab-${dm.scopeId.routeParam}'),
      directMessage: dm,
      unreadCount: unreadState.dmUnreadCount(dm.scopeId),
      isPinned: isPinned,
      isOnline: isOnline,
      onTap: () {
        unreadStore.markDmRead(dm.scopeId);
        context.push(homeStore.directMessageRoutePath(dm.scopeId));
      },
      onTogglePin: () => isPinned
          ? homeStore.unpinDirectMessage(dm.scopeId)
          : homeStore.pinDirectMessage(dm.scopeId),
      onHide: () => homeStore.hideDm(dm.scopeId),
    );
  }

  Widget _buildHiddenDmsTile({
    required HomeListState state,
    required HomeListStore homeStore,
    required ChannelUnreadStore unreadStore,
    required AppLocalizations l10n,
  }) {
    return ListTile(
      key: const ValueKey('dms-tab-hidden'),
      leading: const Icon(Icons.visibility_off_outlined),
      title: Text(
        l10n.homeHiddenConversationsCount(
          state.hiddenDirectMessages.length,
        ),
      ),
      onTap: () => _showHiddenDmsSheet(homeStore, unreadStore),
    );
  }

  void _showHiddenDmsSheet(
    HomeListStore homeStore,
    ChannelUnreadStore unreadStore,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Consumer(
          builder: (_, ref, __) {
            final hiddenDms =
                ref.watch(homeListStoreProvider).hiddenDirectMessages;
            if (hiddenDms.isEmpty) {
              Navigator.of(sheetContext).pop();
              return const SizedBox.shrink();
            }
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        context.l10n.homeHiddenConversationsTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final dm in hiddenDms)
                            ListTile(
                              key: ValueKey(
                                'hidden-dm-${dm.scopeId.routeParam}',
                              ),
                              leading: const Icon(Icons.person_outline),
                              title: Text(dm.title),
                              trailing: TextButton(
                                key: ValueKey(
                                  'unhide-dm-${dm.scopeId.routeParam}',
                                ),
                                onPressed: () => homeStore.unhideDm(dm.scopeId),
                                child: Text(context.l10n.homeUnhide),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showNewDmDialog() async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;
    final pageContext = context;

    final channelId = await showDialog<String>(
      context: pageContext,
      builder: (_) => NewDmDialog(serverId: serverId),
    );

    if (channelId != null && mounted && pageContext.mounted) {
      pageContext.go('/servers/${serverId.value}/dms/$channelId');
    }
  }
}

class _DmsNoServerState extends StatelessWidget {
  const _DmsNoServerState({required this.message});

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

class _DmsErrorState extends StatelessWidget {
  const _DmsErrorState({
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
