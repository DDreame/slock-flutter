import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_admin_realtime_binding.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/application/home_tasks_realtime_binding.dart';
import 'package:slock_app/features/home/application/home_unread_item.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/presentation/widgets/server_switcher_sheet.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/features/unread/data/channel_unread_repository_provider.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_state.dart';
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
    ref.watch(homeTasksRealtimeBindingProvider);
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
                _HomeTasksSection(
                  key: const ValueKey('home-card-tasks'),
                  taskItems: state.taskItems,
                  channels: [
                    ...state.pinnedChannels,
                    ...state.channels,
                  ],
                  onViewAll: () => _pushServerRoute('tasks'),
                ),
                const SizedBox(height: AppSpacing.md),
                _HomeUnreadSection(
                  key: const ValueKey('home-card-unread'),
                  threadItems: state.threadItems,
                  channels: [
                    ...state.pinnedChannels,
                    ...state.channels,
                  ],
                  directMessages: [
                    ...state.pinnedDirectMessages,
                    ...state.directMessages,
                  ],
                  unreadState: unreadState,
                ),
                const SizedBox(height: AppSpacing.md),
                _HomeAgentsSection(
                  key: const ValueKey('home-card-agents'),
                  agents: [
                    ...state.pinnedAgents,
                    ...state.agents,
                  ],
                  onViewAll: () => _pushServerRoute('agents'),
                  onAgentTap: (agent) {
                    final sid = ref.read(activeServerScopeIdProvider)?.value;
                    if (sid == null) return;
                    context.push(
                      '/servers/$sid/agents/${agent.id}',
                    );
                  },
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
    this.onViewAll,
    required this.child,
  });

  final Color accentColor;
  final String title;
  final VoidCallback? onViewAll;
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
                      if (onViewAll != null)
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

/// Priority order for sorting agents by activity.
/// Lower = more prominent (shown first).
/// Stopped agents always sort last regardless of stale activity value.
int _agentActivityPriority(AgentItem agent) {
  if (agent.status == 'stopped') return 4;
  return switch (agent.activity) {
    'working' => 0,
    'thinking' => 1,
    'error' => 2,
    'online' => 3,
    _ => 4, // offline
  };
}

const _maxVisibleAgents = 3;

/// Whether an agent is considered "active" (working/thinking/error/online) —
/// these are shown as individual rows.
/// Stopped agents are never active regardless of stale activity value.
bool _isAgentActive(AgentItem agent) {
  if (agent.status == 'stopped') return false;
  return agent.activity == 'working' ||
      agent.activity == 'thinking' ||
      agent.activity == 'error' ||
      agent.activity == 'online';
}

class _HomeAgentsSection extends StatelessWidget {
  const _HomeAgentsSection({
    super.key,
    required this.agents,
    required this.onViewAll,
    required this.onAgentTap,
  });

  final List<AgentItem> agents;
  final VoidCallback onViewAll;
  final void Function(AgentItem agent) onAgentTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    // Sort: working/thinking/error → online → stopped/offline
    final sorted = List.of(agents)
      ..sort(
        (a, b) =>
            _agentActivityPriority(a).compareTo(_agentActivityPriority(b)),
      );

    final active = sorted.where((a) => _isAgentActive(a)).toList();
    final stopped = sorted.where((a) => !_isAgentActive(a)).toList();

    // Chip counts — each bucket counted independently;
    // exclude stopped agents from online/error counts.
    final online = agents
        .where(
          (a) => a.activity == 'online' && a.status != 'stopped',
        )
        .length;
    final errorCount = agents
        .where(
          (a) => a.activity == 'error' && a.status != 'stopped',
        )
        .length;

    // Show up to 3 active agents as rows
    final visibleAgents = active.take(_maxVisibleAgents).toList();
    final hasActiveRows = visibleAgents.isNotEmpty;

    return _SummaryCardBase(
      accentColor: colors.primary,
      title: l10n.homeCardAgents,
      onViewAll: onViewAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total count + subtitle
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

          // Status chips
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
              if (errorCount > 0)
                _StatusChip(
                  label: l10n.homeCardAgentsError(errorCount),
                  color: colors.error,
                ),
              if (stopped.isNotEmpty)
                _StatusChip(
                  label: l10n.homeCardAgentsStopped(
                    stopped.length,
                  ),
                  color: colors.warning,
                ),
            ],
          ),

          // Active agent rows or empty state
          if (hasActiveRows) ...[
            const SizedBox(height: AppSpacing.md),
            for (final agent in visibleAgents)
              _MiniAgentRow(
                key: ValueKey('agent-row-${agent.id}'),
                agent: agent,
                onTap: () => onAgentTap(agent),
              ),
          ] else if (agents.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const _AgentsEmptyState(
              key: ValueKey('home-agents-empty'),
            ),
          ],

          // Fold: stopped/offline summary
          if (stopped.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _AgentFoldSummary(
              key: const ValueKey('home-agents-fold'),
              stoppedCount: stopped.length,
              onTap: onViewAll,
            ),
          ],
        ],
      ),
    );
  }
}

class _AgentsEmptyState extends StatelessWidget {
  const _AgentsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    return Row(
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 20,
          color: colors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          l10n.homeCardAgentsEmpty,
          style: AppTypography.bodySmall.copyWith(
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _AgentFoldSummary extends StatelessWidget {
  const _AgentFoldSummary({
    super.key,
    required this.stoppedCount,
    required this.onTap,
  });

  final int stoppedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    final text = l10n.homeCardAgentsStopped(stoppedCount);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
            Text(
              '${l10n.homeCardViewAll} \u2192',
              style: AppTypography.caption.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAgentRow extends StatelessWidget {
  const _MiniAgentRow({
    super.key,
    required this.agent,
    this.onTap,
  });

  final AgentItem agent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final dotColor = switch (agent.activity) {
      'online' || 'thinking' || 'working' => colors.success,
      'error' => colors.error,
      _ => colors.textTertiary,
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
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
                      agent.label.isNotEmpty
                          ? agent.label[0].toUpperCase()
                          : '?',
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
              _activityText(context, agent.activity),
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _activityText(
    BuildContext context,
    String activity,
  ) {
    final l10n = context.l10n;
    return switch (activity) {
      'online' => l10n.homeCardAgentActivityOnline,
      'thinking' => l10n.homeCardAgentActivityThinking,
      'working' => l10n.homeCardAgentActivityWorking,
      'error' => l10n.homeCardAgentActivityError,
      _ => l10n.homeCardAgentActivityOffline,
    };
  }
}

// ---------------------------------------------------------------------------
// Tasks section — detailed task list
// ---------------------------------------------------------------------------

const _maxVisibleTasks = 5;

class _HomeTasksSection extends ConsumerWidget {
  const _HomeTasksSection({
    super.key,
    required this.taskItems,
    required this.channels,
    required this.onViewAll,
  });

  final List<TaskItem> taskItems;
  final List<HomeChannelSummary> channels;
  final VoidCallback onViewAll;

  String _channelName(String channelId) {
    for (final ch in channels) {
      if (ch.scopeId.value == channelId) return ch.name;
    }
    return channelId;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    final now = ref.watch(homeNowProvider);

    // Filter: only in_progress + todo
    final activeTasks = taskItems
        .where(
          (task) => task.status == 'in_progress' || task.status == 'todo',
        )
        .toList();

    // Sort: in_progress first, then todo
    activeTasks.sort((a, b) {
      final aInProgress = a.status == 'in_progress' ? 0 : 1;
      final bInProgress = b.status == 'in_progress' ? 0 : 1;
      return aInProgress.compareTo(bInProgress);
    });

    final visibleTasks = activeTasks.take(_maxVisibleTasks).toList();
    final overflowCount = activeTasks.length - visibleTasks.length;

    return _SummaryCardBase(
      accentColor: colors.warning,
      title: l10n.homeCardTasks,
      onViewAll: onViewAll,
      child: activeTasks.isEmpty
          ? const _TasksEmptyState(key: ValueKey('home-tasks-empty'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final task in visibleTasks)
                  _TaskItemRow(
                    key: ValueKey('task-item-${task.id}'),
                    task: task,
                    channelName: _channelName(task.channelId),
                    now: now,
                  ),
                if (overflowCount > 0)
                  Padding(
                    key: const ValueKey('home-tasks-overflow'),
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xs,
                    ),
                    child: Text(
                      l10n.homeCardTasksOverflow(overflowCount),
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TasksEmptyState extends StatelessWidget {
  const _TasksEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    return Row(
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 20,
          color: colors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          l10n.homeCardTasksEmpty,
          style: AppTypography.caption.copyWith(
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _TaskItemRow extends StatelessWidget {
  const _TaskItemRow({
    super.key,
    required this.task,
    required this.channelName,
    required this.now,
  });

  final TaskItem task;
  final String channelName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    final isInProgress = task.status == 'in_progress';

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: AppTypography.body.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '#$channelName',
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                    if (task.claimedByName != null) ...[
                      Text(
                        ' · ',
                        style: AppTypography.caption.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          task.claimedByName!,
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (isInProgress && task.claimedAt != null)
            Padding(
              key: ValueKey('task-duration-${task.id}'),
              padding: const EdgeInsets.only(
                right: AppSpacing.xs,
              ),
              child: _DurationChip(
                duration: now.difference(task.claimedAt!),
                l10n: l10n,
              ),
            ),
          _TaskStatusChip(
            key: ValueKey('task-status-${task.id}'),
            label: isInProgress
                ? l10n.homeCardTasksInProgress
                : l10n.homeCardTasksTodo,
            color: isInProgress ? colors.primary : colors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.duration,
    required this.l10n,
  });

  final Duration duration;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = duration.inMinutes;
    final hours = duration.inHours;
    final minutes = totalMinutes % 60;

    // Color: blue <1h, orange 1-4h, red >4h
    final Color chipColor;
    if (hours < 1) {
      chipColor = Colors.blue;
    } else if (hours <= 4) {
      chipColor = Colors.orange;
    } else {
      chipColor = Colors.red;
    }

    // Format: <1h → "45m", 1-4h → "2h 15m", >4h → "6h"
    final String text;
    if (hours < 1) {
      text = l10n.homeCardTasksDurationMinutes(totalMinutes);
    } else if (hours <= 4) {
      text = l10n.homeCardTasksDurationHours(hours, minutes);
    } else {
      text = l10n.homeCardTasksDurationHoursOnly(hours);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: chipColor,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _TaskStatusChip extends StatelessWidget {
  const _TaskStatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Unread section
// ---------------------------------------------------------------------------

const _maxVisibleUnreads = 5;

class _HomeUnreadSection extends StatelessWidget {
  const _HomeUnreadSection({
    super.key,
    required this.threadItems,
    required this.channels,
    required this.directMessages,
    required this.unreadState,
  });

  final List<ThreadInboxItem> threadItems;
  final List<HomeChannelSummary> channels;
  final List<HomeDirectMessageSummary> directMessages;
  final ChannelUnreadState unreadState;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    final unreadItems = _buildUnreadItems();

    return _SummaryCardBase(
      accentColor: colors.error,
      title: l10n.homeCardUnread,
      child: unreadItems.isEmpty
          ? const _UnreadEmptyState(
              key: ValueKey('home-unread-empty'),
            )
          : _UnreadListContent(
              key: const ValueKey('home-unread-list'),
              unreadItems: unreadItems,
            ),
    );
  }

  List<HomeUnreadItem> _buildUnreadItems() {
    final items = <HomeUnreadItem>[];

    // Threads with unread > 0
    for (final thread in threadItems) {
      if (thread.unreadCount > 0) {
        items.add(HomeUnreadItem.fromThread(thread));
      }
    }

    // Channels with unread > 0
    for (final entry in unreadState.channelUnreadCounts.entries) {
      if (entry.value > 0) {
        final channel = _findChannel(entry.key);
        if (channel != null) {
          items.add(
            HomeUnreadItem.fromChannel(channel, entry.value),
          );
        }
      }
    }

    // DMs with unread > 0
    for (final entry in unreadState.dmUnreadCounts.entries) {
      if (entry.value > 0) {
        final dm = _findDm(entry.key);
        if (dm != null) {
          items.add(
            HomeUnreadItem.fromDirectMessage(dm, entry.value),
          );
        }
      }
    }

    // Sort by last activity (most recent first), nulls last
    items.sort((a, b) {
      final aTime = a.lastActivityAt;
      final bTime = b.lastActivityAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return items;
  }

  HomeChannelSummary? _findChannel(ChannelScopeId scopeId) {
    for (final ch in channels) {
      if (ch.scopeId == scopeId) return ch;
    }
    return null;
  }

  HomeDirectMessageSummary? _findDm(DirectMessageScopeId scopeId) {
    for (final dm in directMessages) {
      if (dm.scopeId == scopeId) return dm;
    }
    return null;
  }
}

class _UnreadListContent extends ConsumerWidget {
  const _UnreadListContent({
    super.key,
    required this.unreadItems,
  });

  final List<HomeUnreadItem> unreadItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    final now = ref.watch(homeNowProvider);

    final visible = unreadItems.take(_maxVisibleUnreads).toList();
    final overflowCount = unreadItems.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            key: const ValueKey('home-unread-mark-all'),
            onTap: () => _markAllRead(ref),
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.xs,
              ),
              child: Text(
                l10n.homeCardUnreadMarkAllRead,
                style: AppTypography.caption.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        for (final item in visible)
          _UnreadItemRow(
            key: ValueKey('unread-item-${item.id}'),
            item: item,
            now: now,
          ),
        if (overflowCount > 0)
          Padding(
            key: const ValueKey('home-unread-overflow'),
            padding: const EdgeInsets.only(
              top: AppSpacing.xs,
            ),
            child: Text(
              l10n.homeCardUnreadOverflow(overflowCount),
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  void _markAllRead(WidgetRef ref) {
    final markChannel = ref.read(markChannelReadUseCaseProvider);
    final markDm = ref.read(markDmReadUseCaseProvider);

    for (final item in unreadItems) {
      switch (item.kind) {
        case HomeUnreadKind.channel:
          if (item.channelScopeId != null) {
            markChannel(item.channelScopeId!);
          }
        case HomeUnreadKind.directMessage:
          if (item.dmScopeId != null) {
            markDm(item.dmScopeId!);
          }
        case HomeUnreadKind.thread:
          break; // Handled below via HomeListStore.
      }
    }

    // Clear thread unreads locally so threads also disappear.
    if (unreadItems.any((i) => i.kind == HomeUnreadKind.thread)) {
      ref.read(homeListStoreProvider.notifier).clearThreadUnreads();
    }

    // Fire-and-forget server-side bulk read.
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId != null) {
      unawaited(
        ref
            .read(channelUnreadRepositoryProvider)
            .markAllInboxRead(serverId)
            .catchError((_) {}),
      );
    }
  }
}

class _UnreadEmptyState extends StatelessWidget {
  const _UnreadEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    return Row(
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 20,
          color: colors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          l10n.homeCardUnreadEmpty,
          style: AppTypography.caption.copyWith(
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _UnreadItemRow extends ConsumerWidget {
  const _UnreadItemRow({
    super.key,
    required this.item,
    required this.now,
  });

  final HomeUnreadItem item;
  final DateTime now;

  IconData get _kindIcon {
    switch (item.kind) {
      case HomeUnreadKind.thread:
        return Icons.reply;
      case HomeUnreadKind.channel:
        return Icons.tag;
      case HomeUnreadKind.directMessage:
        return Icons.mail_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GestureDetector(
      onTap: () => _navigateTo(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              _kindIcon,
              size: 16,
              color: colors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
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
            if (item.lastActivityAt != null)
              _TimeAgoLabel(
                time: item.lastActivityAt!,
                now: now,
              ),
            const SizedBox(width: AppSpacing.xs),
            _UnreadBadge(count: item.unreadCount),
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

class _TimeAgoLabel extends StatelessWidget {
  const _TimeAgoLabel({
    required this.time,
    required this.now,
  });

  final DateTime time;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    final diff = now.difference(time);

    final String text;
    if (diff.inMinutes < 1) {
      text = l10n.homeCardTimeAgoNow;
    } else if (diff.inHours < 1) {
      text = l10n.homeCardTimeAgoMinutes(diff.inMinutes);
    } else if (diff.inDays < 1) {
      text = l10n.homeCardTimeAgoHours(diff.inHours);
    } else {
      text = l10n.homeCardTimeAgoDays(diff.inDays);
    }

    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: colors.textTertiary,
        fontSize: 11,
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTypography.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
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
