import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/list_action_sheet.dart';
import 'package:slock_app/app/widgets/snackbar_utils.dart';
import 'package:slock_app/app/widgets/app_loading_indicator.dart';
import 'package:slock_app/app/widgets/empty_state_widget.dart';
import 'package:slock_app/app/widgets/role_badge.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/app/widgets/status_glow_ring.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agent_display_status.dart';
import 'package:slock_app/features/agents/application/agent_status_group.dart';
import 'package:slock_app/features/agents/application/agent_status_group_projection.dart';
import 'package:slock_app/features/agents/application/agents_fold_state.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/presentation/widget/agent_form_dialog.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/presence/presentation/widgets/presence_avatar.dart';
import 'package:slock_app/l10n/l10n.dart';

class AgentsPage extends ConsumerStatefulWidget {
  const AgentsPage({super.key, this.agentId, this.serverId});

  final String? agentId;
  final String? serverId;

  @override
  ConsumerState<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends ConsumerState<AgentsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(agentsStoreProvider.notifier).ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    // INV-AGENTS-PAGE-SELECT-1: Narrow to consumed fields only.
    // Excludes machines, activityLogs, isRefreshing — these don't affect
    // the page build tree. activityLogs is consumed in _AgentDetailBody
    // via its own scoped .select().
    final state = ref.watch(
      agentsStoreProvider.select(
        (s) => (
          status: s.status,
          items: s.items,
          isCreating: s.isCreating,
          failure: s.failure,
          savingAgentIds: s.savingAgentIds,
          deletingAgentIds: s.deletingAgentIds,
          controlActionAgentIds: s.controlActionAgentIds,
        ),
      ),
    );
    // INV-NET-DEGRADE-2: surface refresh failure via snackbar only when a
    // refresh completes with failure — not on mutation errors (create/update).
    ref.listen(
      agentsStoreProvider.select((s) => s.isRefreshing),
      (prev, next) {
        if (prev == true && next == false) {
          final s = ref.read(agentsStoreProvider);
          if (s.failure != null && s.status == AgentsStatus.success) {
            _showRefreshFailedSnackBar();
          }
        }
      },
    );

    // Helper to check busy state from record fields.
    bool isBusy(String id) =>
        state.savingAgentIds.contains(id) ||
        state.deletingAgentIds.contains(id) ||
        state.controlActionAgentIds.contains(id);

    if (widget.agentId != null) {
      AgentItem? agent;
      for (final item in state.items) {
        if (item.id == widget.agentId) {
          agent = item;
          break;
        }
      }
      return _AgentDetailScaffold(
        agent: agent,
        isLoading: state.status == AgentsStatus.loading ||
            state.status == AgentsStatus.initial,
        isFailure: state.status == AgentsStatus.failure,
        failureMessage: state.failure?.message,
        onRetry: ref.read(agentsStoreProvider.notifier).retry,
        onEdit: agent == null || isBusy(agent.id) ? null : _editAgent,
        onDelete: agent == null || isBusy(agent.id) ? null : _deleteAgent,
        onStart: agent == null || isBusy(agent.id) ? null : _startAgent,
        onStop: agent == null || isBusy(agent.id) ? null : _stopAgent,
        onReset: agent == null || isBusy(agent.id) ? null : _resetAgent,
        onMessage: agent == null || isBusy(agent.id) ? null : _messageAgent,
      );
    }

    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navAgents),
        actions: [
          if (state.status == AgentsStatus.success)
            state.isCreating
                ? const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    key: const ValueKey('agents-new-btn'),
                    icon: const Icon(Icons.add),
                    tooltip: l10n.agentsNewTooltip,
                    onPressed: _createAgent,
                  ),
        ],
      ),
      body: switch (state.status) {
        AgentsStatus.initial ||
        AgentsStatus.loading =>
          const AppLoadingIndicator(),
        AgentsStatus.failure => _AgentsFailureView(
            message: state.failure?.message ?? 'Failed to load agents.',
            onRetry: ref.read(agentsStoreProvider.notifier).retry,
          ),
        AgentsStatus.success when state.items.isEmpty => const EmptyStateWidget(
            key: ValueKey('agents-empty'),
            icon: Icons.smart_toy_outlined,
            title: 'No agents yet.',
          ),
        AgentsStatus.success => _buildGroupedList(
            state.items,
            colors,
          ),
      },
    );
  }

  Widget _buildGroupedList(
    List<AgentItem> items,
    AppColors colors,
  ) {
    final groups = ref.watch(agentStatusGroupProjectionProvider);
    final active = items.where((a) => a.isActive).length;
    final stopped = items.length - active;

    return _GroupedAgentsListView(
      groups: groups,
      totalActive: active,
      totalStopped: stopped,
      colors: colors,
      onTap: _openAgentDetail,
      onStart: _startAgent,
      onStop: _stopAgent,
      onReset: _resetAgent,
    );
  }

  void _openAgentDetail(AgentItem agent) {
    final serverId =
        widget.serverId ?? ref.read(activeServerScopeIdProvider)?.value;
    if (serverId != null) {
      context.push('/servers/$serverId/agents/${agent.id}');
      return;
    }
    context.push('/agents/${agent.id}');
  }

  String? _resolvedServerId() {
    return widget.serverId ?? ref.read(activeServerScopeIdProvider)?.value;
  }

  Future<AgentMutationInput?> _showAgentFormDialog({AgentItem? agent}) async {
    final serverId = _resolvedServerId();
    if (serverId == null) {
      showAppSnackBar(context, 'Select a server first.');
      return null;
    }

    return showDialog<AgentMutationInput>(
      context: context,
      builder: (dialogContext) {
        return AgentFormDialog(serverId: serverId, initialAgent: agent);
      },
    );
  }

  Future<void> _createAgent() async {
    final input = await _showAgentFormDialog();
    if (input == null) {
      return;
    }

    try {
      await ref.read(agentsStoreProvider.notifier).createAgent(input);
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, 'Agent created.');
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, failure.message ?? 'Failed to create agent.');
    }
  }

  Future<void> _editAgent(AgentItem agent) async {
    final input = await _showAgentFormDialog(agent: agent);
    if (input == null) {
      return;
    }

    try {
      await ref.read(agentsStoreProvider.notifier).updateAgent(agent.id, input);
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, 'Agent updated.');
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, failure.message ?? 'Failed to update agent.');
    }
  }

  Future<void> _deleteAgent(AgentItem agent) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete Agent?'),
              content: Text(
                'Delete ${agent.label}? This removes the agent configuration from the workspace.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('agent-delete-confirm'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    try {
      await ref.read(agentsStoreProvider.notifier).deleteAgent(agent.id);
      if (!mounted) {
        return;
      }

      showAppSnackBar(context, 'Agent deleted.');

      if (widget.agentId != null) {
        // Use GoRouter's canPop instead of Navigator.canPop so the check
        // is consistent with the GoRouter-managed navigation stack.
        if (context.canPop()) {
          context.pop();
        } else {
          final router = GoRouter.maybeOf(context);
          if (router != null) {
            final serverId = _resolvedServerId();
            if (serverId != null) {
              router.go('/servers/$serverId/agents');
            } else {
              router.go('/agents');
            }
          }
        }
      }
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, failure.message ?? 'Failed to delete agent.');
    }
  }

  Future<void> _startAgent(AgentItem agent) async {
    try {
      await ref.read(agentsStoreProvider.notifier).startAgent(agent.id);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(context, failure.message ?? 'Failed to start agent.');
    }
  }

  Future<void> _stopAgent(AgentItem agent) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Stop Agent?'),
              content: Text(
                'Stop ${agent.label}? The agent will finish its current action before stopping.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('agent-stop-confirm'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Stop'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      await ref.read(agentsStoreProvider.notifier).stopAgent(agent.id);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(context, failure.message ?? 'Failed to stop agent.');
    }
  }

  Future<void> _resetAgent(AgentItem agent) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Reset Session?'),
              content: Text(
                'Reset ${agent.label}? This clears the agent\'s conversation history.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('agent-reset-confirm'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      await ref.read(agentsStoreProvider.notifier).resetAgent(agent.id);
      if (!mounted) return;
      showAppSnackBar(context, 'Agent reset.');
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(context, failure.message ?? 'Failed to reset agent.');
    }
  }

  Future<void> _messageAgent(AgentItem agent) async {
    final serverId = _resolvedServerId();
    if (serverId == null) {
      showAppSnackBar(context, 'Select a server first.');
      return;
    }
    try {
      final channelId =
          await ref.read(memberRepositoryProvider).openAgentDirectMessage(
                ServerScopeId(serverId),
                agentId: agent.id,
              );
      if (!mounted) return;
      context.push('/servers/$serverId/dms/$channelId');
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(
          context, failure.message ?? 'Failed to open conversation.');
    }
  }

  void _showRefreshFailedSnackBar() {
    final l10n = context.l10n;
    showAppSnackBarWithAction(
      context,
      l10n.refreshFailedSnackbar,
      actionLabel: l10n.refreshFailedRetry,
      onAction: () => ref.read(agentsStoreProvider.notifier).load(),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats summary
// ---------------------------------------------------------------------------

class _AgentsStatsSummary extends StatelessWidget {
  const _AgentsStatsSummary({
    required this.activeCount,
    required this.stoppedCount,
    required this.colors,
  });

  final int activeCount;
  final int stoppedCount;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('agents-stats-summary'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Text(
        '$activeCount active / $stoppedCount stopped',
        key: const ValueKey('agents-stats-text'),
        style: AppTypography.bodySmall.copyWith(
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status-grouped list view
// ---------------------------------------------------------------------------

class _GroupedAgentsListView extends ConsumerWidget {
  const _GroupedAgentsListView({
    required this.groups,
    required this.totalActive,
    required this.totalStopped,
    required this.colors,
    required this.onTap,
    required this.onStart,
    required this.onStop,
    required this.onReset,
  });

  final List<AgentStatusGroup> groups;
  final int totalActive;
  final int totalStopped;
  final AppColors colors;
  final void Function(AgentItem) onTap;
  final Future<void> Function(AgentItem) onStart;
  final Future<void> Function(AgentItem) onStop;
  final Future<void> Function(AgentItem) onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(agentsFoldStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AgentsStatsSummary(
          activeCount: totalActive,
          stoppedCount: totalStopped,
          colors: colors,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ListView(
            key: const ValueKey('agents-list'),
            padding: const EdgeInsets.only(
              bottom: AppSpacing.lg,
            ),
            children: [
              for (final group in groups)
                _StatusGroupSection(
                  group: group,
                  isCollapsed: collapsed.contains(group.foldKey),
                  colors: colors,
                  onToggle: () => ref
                      .read(
                        agentsFoldStateProvider.notifier,
                      )
                      .toggle(group.foldKey),
                  onTap: onTap,
                  onStart: onStart,
                  onStop: onStop,
                  onReset: onReset,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status group section (collapsible)
// ---------------------------------------------------------------------------

class _StatusGroupSection extends StatelessWidget {
  const _StatusGroupSection({
    required this.group,
    required this.isCollapsed,
    required this.colors,
    required this.onToggle,
    required this.onTap,
    required this.onStart,
    required this.onStop,
    required this.onReset,
  });

  final AgentStatusGroup group;
  final bool isCollapsed;
  final AppColors colors;
  final VoidCallback onToggle;
  final void Function(AgentItem) onTap;
  final Future<void> Function(AgentItem) onStart;
  final Future<void> Function(AgentItem) onStop;
  final Future<void> Function(AgentItem) onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('status-group-${group.foldKey}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusGroupHeader(
          group: group,
          isCollapsed: isCollapsed,
          colors: colors,
          onToggle: onToggle,
        ),
        if (isCollapsed)
          _CollapsedSummary(
            group: group,
            colors: colors,
          )
        else
          for (final agent in group.agents)
            _AgentRow(
              agent: agent,
              colors: colors,
              onTap: onTap,
              onStart: onStart,
              onStop: onStop,
              onReset: onReset,
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status group header
// ---------------------------------------------------------------------------

class _StatusGroupHeader extends StatelessWidget {
  const _StatusGroupHeader({
    required this.group,
    required this.isCollapsed,
    required this.colors,
    required this.onToggle,
  });

  final AgentStatusGroup group;
  final bool isCollapsed;
  final AppColors colors;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
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

    return InkWell(
      key: ValueKey(
        'status-header-${group.foldKey}',
      ),
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.md,
          AppSpacing.pageHorizontal,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              isCollapsed ? Icons.expand_more : Icons.expand_less,
              size: 20,
              color: colors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                displayStatusLabel(group.displayStatus, l10n: context.l10n),
                style: AppTypography.label.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${group.count}',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsed summary line
// ---------------------------------------------------------------------------

class _CollapsedSummary extends StatelessWidget {
  const _CollapsedSummary({
    required this.group,
    required this.colors,
  });

  final AgentStatusGroup group;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey(
        'collapsed-summary-${group.foldKey}',
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal + 24,
        0,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: Text(
        group.mergedSummary(l10n: context.l10n),
        style: AppTypography.bodySmall.copyWith(
          color: colors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agent row
// ---------------------------------------------------------------------------

/// Maps [AgentItem.activity] string to [GlowRingStatus].
GlowRingStatus _mapActivityToGlowStatus(String activity) {
  return switch (activity) {
    'online' => GlowRingStatus.online,
    'thinking' => GlowRingStatus.thinking,
    'working' => GlowRingStatus.working,
    'error' => GlowRingStatus.error,
    'offline' => GlowRingStatus.offline,
    _ => GlowRingStatus.offline,
  };
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({
    required this.agent,
    required this.colors,
    required this.onTap,
    required this.onStart,
    required this.onStop,
    required this.onReset,
  });

  final AgentItem agent;
  final AppColors colors;
  final void Function(AgentItem) onTap;
  final Future<void> Function(AgentItem) onStart;
  final Future<void> Function(AgentItem) onStop;
  final Future<void> Function(AgentItem) onReset;

  @override
  Widget build(BuildContext context) {
    final isStopped = agent.isStopped;

    Widget row = InkWell(
      key: ValueKey('agent-${agent.id}'),
      onTap: () => onTap(agent),
      onLongPress: () => _showAgentActions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.listItemVertical,
        ),
        child: Row(
          children: [
            StatusGlowRing(
              status: _mapActivityToGlowStatus(agent.activity),
              size: 44,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colors.surfaceAlt,
                child: Text(
                  agent.label.isNotEmpty ? agent.label[0].toUpperCase() : '?',
                  style: AppTypography.title.copyWith(color: colors.text),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          agent.label,
                          style: AppTypography.title.copyWith(
                            color: colors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      RoleBadge(
                        label: agent.runtime,
                        color: colors.agentAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _activityLabel(agent.activity, agent.activityDetail),
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isStopped) {
      row = Opacity(
        key: ValueKey('agent-row-opacity-${agent.id}'),
        opacity: 0.5,
        child: row,
      );
    }

    return row;
  }

  Future<void> _showAgentActions(BuildContext context) async {
    final actions = <ListActionItem>[
      if (agent.isStopped)
        const ListActionItem(
          key: 'agent-action-start',
          label: 'Start',
          icon: Icons.play_arrow,
        ),
      if (agent.isActive)
        const ListActionItem(
          key: 'agent-action-stop',
          label: 'Stop',
          icon: Icons.stop,
        ),
      if (agent.isActive)
        const ListActionItem(
          key: 'agent-action-reset',
          label: 'Reset Session',
          icon: Icons.refresh,
        ),
    ];

    final result = await showListActionSheet(
      context: context,
      actions: actions,
      title: agent.label,
    );

    switch (result) {
      case 'agent-action-start':
        onStart(agent);
      case 'agent-action-stop':
        onStop(agent);
      case 'agent-action-reset':
        onReset(agent);
    }
  }
}

// ---------------------------------------------------------------------------
// Agent detail scaffold
// ---------------------------------------------------------------------------

class _AgentDetailScaffold extends StatelessWidget {
  const _AgentDetailScaffold({
    required this.agent,
    required this.isLoading,
    required this.isFailure,
    required this.failureMessage,
    required this.onRetry,
    required this.onEdit,
    required this.onDelete,
    required this.onStart,
    required this.onStop,
    required this.onReset,
    required this.onMessage,
  });

  final AgentItem? agent;
  final bool isLoading;
  final bool isFailure;
  final String? failureMessage;
  final VoidCallback onRetry;
  final Future<void> Function(AgentItem)? onEdit;
  final Future<void> Function(AgentItem)? onDelete;
  final Future<void> Function(AgentItem)? onStart;
  final Future<void> Function(AgentItem)? onStop;
  final Future<void> Function(AgentItem)? onReset;
  final Future<void> Function(AgentItem)? onMessage;

  @override
  Widget build(BuildContext context) {
    if (agent == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Agent')),
        body: isLoading
            ? const AppLoadingIndicator()
            : isFailure
                ? _AgentsFailureView(
                    message: failureMessage ?? 'Failed to load agents.',
                    onRetry: onRetry,
                  )
                : const Center(child: Text('Agent not found.')),
      );
    }

    final a = agent!;
    return Scaffold(
      appBar: AppBar(
        title: Text(a.label),
        actions: [
          IconButton(
            key: const ValueKey('agent-edit-btn'),
            onPressed: onEdit == null ? null : () => onEdit!(a),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: const ValueKey('agent-delete-btn'),
            onPressed: onDelete == null ? null : () => onDelete!(a),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _AgentDetailBody(
        agent: a,
        onStart: onStart,
        onStop: onStop,
        onReset: onReset,
        onMessage: onMessage,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity log loader
// ---------------------------------------------------------------------------

/// Triggers the initial REST load of the activity log for [agentId].
/// Auto-disposed when the detail view is removed from the tree.
final _activityLogLoaderProvider =
    FutureProvider.autoDispose.family<void, String>((ref, agentId) async {
  await ref.read(agentsStoreProvider.notifier).loadActivityLog(agentId);
});

// ---------------------------------------------------------------------------
// Agent detail body
// ---------------------------------------------------------------------------

class _AgentDetailBody extends ConsumerWidget {
  const _AgentDetailBody({
    required this.agent,
    required this.onStart,
    required this.onStop,
    required this.onReset,
    required this.onMessage,
  });

  final AgentItem agent;
  final Future<void> Function(AgentItem)? onStart;
  final Future<void> Function(AgentItem)? onStop;
  final Future<void> Function(AgentItem)? onReset;
  final Future<void> Function(AgentItem)? onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;

    // Trigger REST load of historical activity log entries.
    ref.watch(_activityLogLoaderProvider(agent.id));

    final activityLog = ref.watch(
      agentsStoreProvider.select((state) => state.activityLogFor(agent.id)),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      children: [
        // --- Avatar + glow ring ---
        Center(
          child: StatusGlowRing(
            key: const ValueKey('agent-detail-glow-ring'),
            status: _mapActivityToGlowStatus(agent.activity),
            size: 80,
            child: PresenceAvatar(
              key: ValueKey('agent-detail-presence-${agent.id}'),
              userId: agent.id,
              child: CircleAvatar(
                radius: 34,
                backgroundColor: colors.surfaceAlt,
                child: Text(
                  agent.label.isNotEmpty ? agent.label[0].toUpperCase() : '?',
                  style: AppTypography.displayMedium.copyWith(
                    color: colors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // --- Status text ---
        Center(
          child: Text(
            _activityLabel(agent.activity, agent.activityDetail),
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        if (agent.description != null && agent.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              agent.description!,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),

        // --- Action buttons ---
        _ActionButtonRow(
          agent: agent,
          colors: colors,
          onMessage: onMessage,
          onStart: onStart,
          onStop: onStop,
          onReset: onReset,
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        // --- 2x2 Config grid ---
        _ConfigGrid(
          key: const ValueKey('agent-config-grid'),
          agent: agent,
          colors: colors,
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        // --- Environment Variables ---
        _EnvVarsSection(
          key: const ValueKey('agent-env-vars-section'),
          colors: colors,
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        // --- Activity Log ---
        Text(
          'Activity Log',
          key: const ValueKey('agent-activity-log-section'),
          style: AppTypography.title.copyWith(color: colors.text),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (activityLog.isEmpty)
          Text(
            'No activity log entries.',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          )
        else
          for (final entry in activityLog)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTime(entry.timestamp),
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textTertiary,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.entry,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Action buttons
// ---------------------------------------------------------------------------

class _ActionButtonRow extends StatelessWidget {
  const _ActionButtonRow({
    required this.agent,
    required this.colors,
    required this.onMessage,
    required this.onStart,
    required this.onStop,
    required this.onReset,
  });

  final AgentItem agent;
  final AppColors colors;
  final Future<void> Function(AgentItem)? onMessage;
  final Future<void> Function(AgentItem)? onStart;
  final Future<void> Function(AgentItem)? onStop;
  final Future<void> Function(AgentItem)? onReset;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        // Message — primary filled
        FilledButton.icon(
          key: const ValueKey('agent-message-btn'),
          onPressed: onMessage == null ? null : () => onMessage!(agent),
          icon: const Icon(Icons.message_outlined),
          label: const Text('Message'),
        ),
        if (agent.isStopped)
          FilledButton.icon(
            key: const ValueKey('agent-start-btn'),
            onPressed: onStart == null ? null : () => onStart!(agent),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
          ),
        if (agent.isActive)
          OutlinedButton.icon(
            key: const ValueKey('agent-stop-btn'),
            onPressed: onStop == null ? null : () => onStop!(agent),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error),
            ),
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          ),
        if (agent.isActive)
          OutlinedButton.icon(
            key: const ValueKey('agent-reset-btn'),
            onPressed: onReset == null ? null : () => onReset!(agent),
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2x2 Config grid
// ---------------------------------------------------------------------------

class _ConfigGrid extends StatelessWidget {
  const _ConfigGrid({
    super.key,
    required this.agent,
    required this.colors,
  });

  final AgentItem agent;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ConfigCell(
                label: 'Machine',
                value: agent.machineId ?? '-',
                colors: colors,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ConfigCell(
                label: 'Runtime',
                value: agent.runtime,
                colors: colors,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ConfigCell(
                label: 'Model',
                value: agent.model,
                colors: colors,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ConfigCell(
                label: 'Reasoning',
                value: agent.reasoningEffort ?? '-',
                colors: colors,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConfigCell extends StatelessWidget {
  const _ConfigCell({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.body.copyWith(color: colors.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Environment Variables section
// ---------------------------------------------------------------------------

class _EnvVarsSection extends StatelessWidget {
  const _EnvVarsSection({super.key, required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Environment Variables',
                style: AppTypography.title.copyWith(color: colors.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SectionCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'No environment variables',
              key: const ValueKey('agent-env-vars-empty'),
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Failure view
// ---------------------------------------------------------------------------

class _AgentsFailureView extends StatelessWidget {
  const _AgentsFailureView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _activityLabel(String activity, String? detail) {
  return switch (activity) {
    'online' => 'Online',
    'thinking' => 'Thinking...',
    'working' => detail ?? 'Working...',
    'error' => 'Error${detail != null ? ': $detail' : ''}',
    'offline' => 'Offline',
    _ => activity,
  };
}
