import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_admin_realtime_binding.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/presentation/widgets/server_switcher_sheet.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    ref.watch(homeAdminRealtimeBindingProvider);
    final state = ref.watch(homeListStoreProvider);
    final homeStore = ref.read(homeListStoreProvider.notifier);
    final unreadState = ref.watch(channelUnreadStoreProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: _HomeAppBarTitle(
          onTap: () => showServerSwitcherSheet(context),
        ),
        actions: [
          IconButton(
            key: const ValueKey('home-settings-button'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTooltip,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: switch (state.status) {
        HomeListStatus.noActiveServer => _HomeNoServerState(
            onSelectServer: () => showServerSwitcherSheet(context),
          ),
        HomeListStatus.initial || HomeListStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        HomeListStatus.failure => _HomeErrorState(
            message: state.failure?.message ?? l10n.homeLoadFailedFallback,
            onRetry: homeStore.retry,
          ),
        HomeListStatus.success => RefreshIndicator(
            key: const ValueKey('home-refresh-indicator'),
            onRefresh: homeStore.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.md,
                AppSpacing.pageHorizontal,
                AppSpacing.xl,
              ),
              children: [
                _AgentsSummaryCard(
                  key: const ValueKey('home-card-agents'),
                  agents: [
                    ...state.pinnedAgents,
                    ...state.agents,
                  ],
                  onViewAll: () => _pushServerRoute('agents'),
                ),
                const SizedBox(height: AppSpacing.md),
                _ChannelsSummaryCard(
                  key: const ValueKey('home-card-channels'),
                  channelCount:
                      state.channels.length + state.pinnedChannels.length,
                  unreadCount: unreadState.channelUnreadCounts.values.fold(
                    0,
                    (sum, c) => sum + c,
                  ),
                  onViewAll: () => _pushServerRoute('channels'),
                ),
                const SizedBox(height: AppSpacing.md),
                _TasksSummaryCard(
                  key: const ValueKey('home-card-tasks'),
                  taskCount: state.taskCount,
                  onViewAll: () => _pushServerRoute('tasks'),
                ),
                const SizedBox(height: AppSpacing.md),
                _ThreadsSummaryCard(
                  key: const ValueKey('home-card-threads'),
                  threadItems: state.threadItems,
                  onViewAll: () => _pushServerRoute('threads'),
                ),
              ],
            ),
          ),
      },
    );
  }

  void _pushServerRoute(String routeSuffix) {
    final serverId = ref.read(activeServerScopeIdProvider)?.value;
    if (serverId == null) return;
    context.push('/servers/$serverId/$routeSuffix');
  }
}

// ---------------------------------------------------------------------------
// Summary card base
// ---------------------------------------------------------------------------

class _SummaryCardBase extends StatelessWidget {
  const _SummaryCardBase({
    required this.accentColor,
    required this.title,
    required this.onViewAll,
    required this.child,
  });

  final Color accentColor;
  final String title;
  final VoidCallback onViewAll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: accentColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      GestureDetector(
                        key: ValueKey(
                          'card-view-all-${title.toLowerCase()}',
                        ),
                        onTap: onViewAll,
                        child: Text(
                          '${l10n.homeCardViewAll} \u2192',
                          style: AppTypography.caption.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agents summary card
// ---------------------------------------------------------------------------

class _AgentsSummaryCard extends StatelessWidget {
  const _AgentsSummaryCard({
    super.key,
    required this.agents,
    required this.onViewAll,
  });

  final List<AgentItem> agents;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    final online =
        agents.where((a) => a.isActive && a.activity != 'error').length;
    final error = agents.where((a) => a.activity == 'error').length;
    final stopped = agents.where((a) => !a.isActive).length;

    return _SummaryCardBase(
      accentColor: colors.primary,
      title: l10n.homeCardAgents,
      onViewAll: onViewAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${agents.length}',
            style: AppTypography.displayMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.homeCardAgentsSubtitle,
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (online > 0)
                _StatusChip(
                  label: l10n.homeCardAgentsOnline(online),
                  color: colors.success,
                ),
              if (error > 0)
                _StatusChip(
                  label: l10n.homeCardAgentsError(error),
                  color: colors.error,
                ),
              if (stopped > 0)
                _StatusChip(
                  label: l10n.homeCardAgentsStopped(stopped),
                  color: colors.warning,
                ),
            ],
          ),
          if (agents.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final agent in agents.take(3)) _MiniAgentRow(agent: agent),
          ],
        ],
      ),
    );
  }
}

class _MiniAgentRow extends StatelessWidget {
  const _MiniAgentRow({required this.agent});

  final AgentItem agent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final dotColor = switch (agent.activity) {
      'online' || 'thinking' || 'working' => colors.success,
      'error' => colors.error,
      _ => colors.textTertiary,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colors.primary.withAlpha(20),
                  child: Text(
                    agent.label.isNotEmpty ? agent.label[0].toUpperCase() : '?',
                    style: AppTypography.caption.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              agent.label,
              style: AppTypography.bodySmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _activityText(agent.activity),
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  String _activityText(String activity) {
    return switch (activity) {
      'online' => 'idle',
      'thinking' => 'thinking',
      'working' => 'working',
      'error' => 'error',
      _ => 'offline',
    };
  }
}

// ---------------------------------------------------------------------------
// Channels summary card
// ---------------------------------------------------------------------------

class _ChannelsSummaryCard extends StatelessWidget {
  const _ChannelsSummaryCard({
    super.key,
    required this.channelCount,
    required this.unreadCount,
    required this.onViewAll,
  });

  final int channelCount;
  final int unreadCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    return _SummaryCardBase(
      accentColor: colors.agentAccent,
      title: l10n.homeCardChannels,
      onViewAll: onViewAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$channelCount',
            style: AppTypography.displayMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.homeCardChannelsSubtitle,
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                _StatusChip(
                  label: l10n.homeCardChannelsUnread(unreadCount),
                  color: colors.primary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tasks summary card
// ---------------------------------------------------------------------------

class _TasksSummaryCard extends StatelessWidget {
  const _TasksSummaryCard({
    super.key,
    required this.taskCount,
    required this.onViewAll,
  });

  final int taskCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    return _SummaryCardBase(
      accentColor: colors.warning,
      title: l10n.homeCardTasks,
      onViewAll: onViewAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$taskCount',
            style: AppTypography.displayMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.homeCardTasksSubtitle,
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Threads summary card with filter chips
// ---------------------------------------------------------------------------

enum _ThreadFilter { active, done, all }

class _ThreadsSummaryCard extends StatefulWidget {
  const _ThreadsSummaryCard({
    super.key,
    required this.threadItems,
    required this.onViewAll,
  });

  final List<ThreadInboxItem> threadItems;
  final VoidCallback onViewAll;

  @override
  State<_ThreadsSummaryCard> createState() => _ThreadsSummaryCardState();
}

class _ThreadsSummaryCardState extends State<_ThreadsSummaryCard> {
  _ThreadFilter _filter = _ThreadFilter.active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    final activeItems =
        widget.threadItems.where((t) => t.unreadCount > 0).toList();
    final doneItems =
        widget.threadItems.where((t) => t.unreadCount == 0).toList();

    final filtered = switch (_filter) {
      _ThreadFilter.active => activeItems,
      _ThreadFilter.done => doneItems,
      _ThreadFilter.all => widget.threadItems,
    };

    return _SummaryCardBase(
      accentColor: colors.primaryLight,
      title: l10n.homeCardThreads,
      onViewAll: widget.onViewAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _FilterChip(
                key: const ValueKey('thread-filter-active'),
                label: l10n.homeCardThreadsFilterActive,
                count: activeItems.length,
                isSelected: _filter == _ThreadFilter.active,
                onTap: () => setState(() => _filter = _ThreadFilter.active),
              ),
              const SizedBox(width: AppSpacing.sm),
              _FilterChip(
                key: const ValueKey('thread-filter-done'),
                label: l10n.homeCardThreadsFilterDone,
                count: doneItems.length,
                isSelected: _filter == _ThreadFilter.done,
                onTap: () => setState(() => _filter = _ThreadFilter.done),
              ),
              const SizedBox(width: AppSpacing.sm),
              _FilterChip(
                key: const ValueKey('thread-filter-all'),
                label: l10n.homeCardThreadsFilterAll,
                isSelected: _filter == _ThreadFilter.all,
                onTap: () => setState(() => _filter = _ThreadFilter.all),
              ),
            ],
          ),
          if (filtered.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final item in filtered.take(3)) _ThreadItemRow(item: item),
          ],
          if (filtered.isEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'No threads',
              key: const ValueKey('home-threads-empty'),
              style: AppTypography.bodySmall.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isSelected ? colors.primary : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: AppTypography.caption.copyWith(
                  color: isSelected ? colors.primary : colors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThreadItemRow extends StatelessWidget {
  const _ThreadItemRow({required this.item});

  final ThreadInboxItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.title != null)
            Text(
              item.title!,
              style: AppTypography.caption.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (item.preview != null)
            Text(
              item.preview!,
              style: AppTypography.bodySmall.copyWith(
                color: colors.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                l10n.homeCardThreadsReplies(item.replyCount),
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              if (item.lastReplyAt != null) ...[
                Text(
                  ' \u00b7 ',
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
                Text(
                  _timeAgo(item.lastReplyAt!),
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
              if (item.unreadCount > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusSm,
                    ),
                  ),
                  child: Text(
                    l10n.homeCardThreadsNew(item.unreadCount),
                    style: AppTypography.caption.copyWith(
                      color: colors.primaryForeground,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ---------------------------------------------------------------------------
// Status chip
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// State widgets
// ---------------------------------------------------------------------------

class _HomeNoServerState extends StatelessWidget {
  const _HomeNoServerState({required this.onSelectServer});

  final VoidCallback onSelectServer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.homeNoServerMessage,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onSelectServer,
              child: Text(context.l10n.homeSelectWorkspace),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
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
              child: Text(context.l10n.homeRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeAppBarTitle extends ConsumerWidget {
  const _HomeAppBarTitle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeServer = ref.watch(activeServerScopeIdProvider);
    final serverListState = ref.watch(serverListStoreProvider);

    String title = 'Slock';
    if (activeServer != null &&
        serverListState.status == ServerListStatus.success) {
      for (final server in serverListState.servers) {
        if (server.id == activeServer.value) {
          title = server.name;
          break;
        }
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(title, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}
