import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/app/widgets/skeleton_card.dart';
import 'package:slock_app/app/widgets/snackbar_utils.dart';
import 'package:slock_app/features/agents/application/agent_display_status.dart';
import 'package:slock_app/features/agents/application/agent_status_group.dart';
import 'package:slock_app/features/agents/application/agent_status_group_projection.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/application/home_task_section_provider.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/presentation/widgets/server_switcher_sheet.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/l10n/l10n.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      homeListStoreProvider.select((s) => (
            status: s.status,
            failure: s.failure,
            isRefreshing: s.isRefreshing,
            taskLoadFailure: s.taskLoadFailure,
          )),
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: _HomeAppBarTitle(
          onTap: () => showServerSwitcherSheet(context),
        ),
        actions: [
          IconButton(
            key: const ValueKey('home-search-button'),
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              final serverId =
                  ref.read(activeServerScopeIdProvider)?.value ?? '';
              context.push('/servers/$serverId/search');
            },
          ),
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
        HomeListStatus.initial || HomeListStatus.loading => ListView(
            key: const ValueKey('home-skeleton'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.md,
              AppSpacing.pageHorizontal,
              AppSpacing.xl,
            ),
            children: const [
              SkeletonCard(key: ValueKey('home-skeleton-card-0')),
              SizedBox(height: AppSpacing.md),
              SkeletonCard(key: ValueKey('home-skeleton-card-1')),
              SizedBox(height: AppSpacing.md),
              SkeletonCard(key: ValueKey('home-skeleton-card-2')),
            ],
          ),
        HomeListStatus.failure => _HomeErrorState(
            message: state.failure?.userMessage(l10n) ?? l10n.errorUnknown,
            onRetry: homeStore.retry,
          ),
        HomeListStatus.success => Column(
            children: [
              if (state.isRefreshing)
                const LinearProgressIndicator(
                  key: ValueKey('home-refreshing'),
                  minHeight: 2,
                ),
              Expanded(
                child: RefreshIndicator(
                  key: const ValueKey('home-refresh-indicator'),
                  onRefresh: homeStore.refresh,
                  child: Semantics(
                    label: 'Home overview',
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageHorizontal,
                        AppSpacing.md,
                        AppSpacing.pageHorizontal,
                        AppSpacing.xl,
                      ),
                      itemCount: 3,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (_, index) => switch (index) {
                        0 => _HomeTasksSection(
                            key: const ValueKey('home-card-tasks'),
                            taskLoadFailure: state.taskLoadFailure,
                            onViewAll: () => _pushServerRoute('tasks'),
                          ),
                        1 => _InboxUnreadSection(
                            key: const ValueKey('home-card-unread'),
                            onViewAll: () => _pushServerRoute('unread'),
                          ),
                        2 => _HomeAgentsSection(
                            key: const ValueKey('home-card-agents'),
                            onViewAll: () => _pushServerRoute('agents'),
                          ),
                        _ => const SizedBox.shrink(),
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
      },
    );
  }

  void _pushServerRoute(String routeSuffix) {
    final serverId = ref.read(activeServerScopeIdProvider)?.value;
    if (serverId == null) return;
    context.push('/servers/$serverId/$routeSuffix');
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
                        Semantics(
                          button: true,
                          label: '${l10n.homeCardViewAll} $title',
                          child: GestureDetector(
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

const _maxVisibleGroups = 4;

class _HomeAgentsSection extends ConsumerStatefulWidget {
  const _HomeAgentsSection({
    super.key,
    required this.onViewAll,
  });

  final VoidCallback onViewAll;

  @override
  ConsumerState<_HomeAgentsSection> createState() => _HomeAgentsSectionState();
}

class _HomeAgentsSectionState extends ConsumerState<_HomeAgentsSection> {
  @override
  void initState() {
    super.initState();
    // INV-HOME-AGENTS-LOAD-GUARD-1: Delegate to ensureLoaded() instead of
    // manually reimplementing the status guard.
    Future.microtask(
        () => ref.read(agentsStoreProvider.notifier).ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    final groups = ref.watch(agentStatusGroupProjectionProvider);
    final agentsSnap = ref.watch(
      agentsStoreProvider
          .select((s) => (count: s.items.length, status: s.status)),
    );
    final totalCount = agentsSnap.count;
    final visibleGroups = groups.take(_maxVisibleGroups).toList();

    // Reload on server switch.
    ref.listen(activeServerScopeIdProvider, (_, __) {
      ref.read(agentsStoreProvider.notifier).load();
    });

    return _SummaryCardBase(
      accentColor: colors.primary,
      title: l10n.homeCardAgents,
      onViewAll: widget.onViewAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total count + subtitle
          Text(
            '$totalCount',
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

          // Group summaries
          if (visibleGroups.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final group in visibleGroups)
              _AgentGroupRow(
                key: ValueKey('agent-group-${group.foldKey}'),
                group: group,
              ),
          ] else if (totalCount > 0 &&
              agentsSnap.status == AgentsStatus.success) ...[
            const SizedBox(height: AppSpacing.md),
            const _AgentsEmptyState(
              key: ValueKey('home-agents-empty'),
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

class _AgentGroupRow extends StatelessWidget {
  const _AgentGroupRow({
    super.key,
    required this.group,
  });

  final AgentStatusGroup group;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final dotColor = switch (group.displayStatus) {
      AgentDisplayStatus.thinking ||
      AgentDisplayStatus.working =>
        colors.success,
      AgentDisplayStatus.error => colors.error,
      AgentDisplayStatus.online => colors.success,
      AgentDisplayStatus.offline ||
      AgentDisplayStatus.stopped =>
        colors.textTertiary,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              group.mergedSummary(l10n: context.l10n),
              style: AppTypography.bodySmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tasks section — detailed task list
// ---------------------------------------------------------------------------

class _HomeTasksSection extends ConsumerWidget {
  const _HomeTasksSection({
    super.key,
    required this.onViewAll,
    this.taskLoadFailure,
  });

  final VoidCallback onViewAll;
  final AppFailure? taskLoadFailure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    final now = ref.watch(homeNowProvider).value ?? DateTime.now();

    // Memoized filtered+sorted+sliced task list from provider.
    final visibleTasks = ref.watch(homeTaskSectionProvider);

    // INV-SELECT-669: Use .select() to derive active count from the store
    // instead of O(n) inline .where() on every rebuild.
    final activeCount = ref.watch(
      homeListStoreProvider.select(
        (s) => s.taskItems
            .where(
              (task) => task.status == 'in_progress' || task.status == 'todo',
            )
            .length,
      ),
    );
    final overflowCount = activeCount - visibleTasks.length;

    return _SummaryCardBase(
      accentColor: colors.warning,
      title: l10n.homeCardTasks,
      onViewAll: onViewAll,
      child: taskLoadFailure != null
          ? _TasksUnavailableState(
              key: const ValueKey('home-tasks-unavailable'),
              message: taskLoadFailure!.userMessage(l10n),
              onRetry: () => ref.read(homeListStoreProvider.notifier).refresh(),
            )
          : visibleTasks.isEmpty
              ? const _TasksEmptyState(key: ValueKey('home-tasks-empty'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final task in visibleTasks)
                      _TaskItemRow(
                        key: ValueKey('task-item-${task.taskId}'),
                        task: task,
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

class _TasksUnavailableState extends StatelessWidget {
  const _TasksUnavailableState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Row(
      children: [
        Icon(
          Icons.error_outline,
          size: 20,
          color: colors.error,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: onRetry,
          child: Icon(
            Icons.refresh,
            size: 20,
            color: colors.primary,
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
    required this.now,
  });

  final HomeTaskItem task;
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
                      '#${task.channelName}',
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
              key: ValueKey('task-duration-${task.taskId}'),
              padding: const EdgeInsets.only(
                right: AppSpacing.xs,
              ),
              child: _DurationChip(
                duration: now.difference(task.claimedAt!),
                l10n: l10n,
              ),
            ),
          _TaskStatusChip(
            key: ValueKey('task-status-${task.taskId}'),
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

/// Inbox-backed unread section that consumes canonical [InboxStore].
class _InboxUnreadSection extends ConsumerStatefulWidget {
  const _InboxUnreadSection({super.key, this.onViewAll});

  final VoidCallback? onViewAll;

  @override
  ConsumerState<_InboxUnreadSection> createState() =>
      _InboxUnreadSectionState();
}

class _InboxUnreadSectionState extends ConsumerState<_InboxUnreadSection> {
  @override
  void initState() {
    super.initState();
    // Trigger initial load if inbox hasn't been loaded yet.
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
    final projectionState = ref.watch(unreadSourceProjectionProvider);
    final unreadItems = projectionState.visibleSources;

    return _SummaryCardBase(
      accentColor: colors.error,
      title: l10n.homeCardUnread,
      onViewAll: widget.onViewAll,
      child: !projectionState.isLoaded
          ? const _UnreadEmptyState(
              key: ValueKey('home-unread-loading'),
            )
          : unreadItems.isEmpty
              ? const _UnreadEmptyState(
                  key: ValueKey('home-unread-empty'),
                )
              : _InboxUnreadListContent(
                  key: const ValueKey('home-unread-list'),
                  unreadItems: unreadItems,
                  onViewAll: widget.onViewAll,
                ),
    );
  }
}

class _InboxUnreadListContent extends ConsumerWidget {
  const _InboxUnreadListContent({
    super.key,
    required this.unreadItems,
    this.onViewAll,
  });

  final List<ConversationProjection> unreadItems;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    final now = ref.watch(homeNowProvider).value ?? DateTime.now();

    final visible = unreadItems.take(_maxVisibleUnreads).toList();
    final overflowCount = unreadItems.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visible.length; i++)
          _UnreadItemRow(
            key: ValueKey('unread-item-$i'),
            item: visible[i],
            now: now,
          ),
        if (overflowCount > 0)
          GestureDetector(
            key: const ValueKey('home-unread-overflow'),
            onTap: onViewAll,
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
              ),
              child: Text(
                l10n.homeCardUnreadOverflow(overflowCount),
                style: AppTypography.caption.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
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

  final ConversationProjection item;
  final DateTime now;

  /// Z2-style type glyph and theme-safe badge color per kind.
  /// Colors: THREAD=purple(primary), CHANNEL=teal, DM=blue.
  (String glyph, Color Function(AppColors) colorFn) get _kindBadge {
    switch (item.kind) {
      case ConversationProjectionKind.thread:
        return ('\u21a9', (c) => c.primary);
      case ConversationProjectionKind.channel:
        return ('#', (_) => const Color(0xFF14B8A6));
      case ConversationProjectionKind.dm:
        return ('\u2709', (_) => const Color(0xFF2196F3));
    }
  }

  /// Z2 type pill label per kind.
  String get _typePillLabel {
    switch (item.kind) {
      case ConversationProjectionKind.thread:
        return 'THREAD';
      case ConversationProjectionKind.channel:
        return 'CHANNEL';
      case ConversationProjectionKind.dm:
        return 'DM';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final (glyph, colorFn) = _kindBadge;
    final badgeColor = colorFn(colors);

    // Build line 3: "senderName: previewText"
    final line3Text = _buildPreviewLine();

    return Semantics(
      label: '${item.title}: ${_buildPreviewLine()}',
      child: GestureDetector(
        onTap: () => _navigateTo(context, ref),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left icon: kind glyph badge
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  key: ValueKey(
                      'unread-kind-${item.kind == ConversationProjectionKind.dm ? 'directMessage' : item.kind.name}'),
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
                    semanticsLabel: item.kind.name,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Three-line content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: Type pill + source + time
                    Row(
                      children: [
                        // Type pill
                        Container(
                          key: ValueKey('unread-pill-${item.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            _typePillLabel,
                            style: TextStyle(
                              fontSize: 9,
                              color: badgeColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Source label
                        if (item.sourceLabel != null)
                          Expanded(
                            child: Text(
                              item.sourceLabel!,
                              key: ValueKey('unread-source-${item.id}'),
                              style: AppTypography.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        else
                          const Spacer(),
                        // Time
                        if (item.lastActivityAt != null) ...[
                          const SizedBox(width: 4),
                          _TimeAgoLabel(
                            time: item.lastActivityAt!,
                            now: now,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Line 2: Destination title (bold)
                    Text(
                      item.title,
                      key: ValueKey('unread-title-${item.id}'),
                      style: AppTypography.body.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Line 3: senderName: previewText (always shown)
                    const SizedBox(height: 2),
                    Text(
                      line3Text,
                      key: ValueKey('unread-preview-${item.id}'),
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Unread badge
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _UnreadBadge(count: item.unreadCount),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build "senderName: previewText" for line 3.
  /// previewText is always non-null via ConversationProjection contract.
  String _buildPreviewLine() {
    if (item.senderName != null) {
      return '${item.senderName}: ${item.previewText}';
    }
    return item.previewText;
  }

  void _navigateTo(BuildContext context, WidgetRef ref) {
    switch (item.kind) {
      case ConversationProjectionKind.thread:
        if (item.threadRouteTarget != null) {
          context.push(item.threadRouteTarget!.toLocation());
        }
      case ConversationProjectionKind.channel:
        if (item.channelScopeId != null) {
          ref.read(markChannelReadUseCaseProvider)(
            item.channelScopeId!,
          );
          final sid = item.channelScopeId!.serverId.routeParam;
          final cid = item.channelScopeId!.routeParam;
          context.push('/servers/$sid/channels/$cid');
        }
      case ConversationProjectionKind.dm:
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
    final serverSnap = ref.watch(
      serverListStoreProvider.select(
        (s) => (status: s.status, servers: s.servers),
      ),
    );

    String title = 'Slock';
    if (activeServer != null && serverSnap.status == ServerListStatus.success) {
      for (final server in serverSnap.servers) {
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
