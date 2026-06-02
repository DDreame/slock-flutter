import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/app_loading_indicator.dart';
import 'package:slock_app/app/widgets/empty_state_widget.dart';
import 'package:slock_app/app/widgets/snackbar_utils.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agent_display_status.dart';
import 'package:slock_app/features/agents/application/agent_status_group.dart';
import 'package:slock_app/features/agents/application/agent_status_group_projection.dart';
import 'package:slock_app/features/agents/application/agents_fold_state.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page_helpers.dart';
import 'package:slock_app/features/agents/presentation/widgets/agent_detail_view.dart';
import 'package:slock_app/features/agents/presentation/widgets/agent_form_dialog.dart';
import 'package:slock_app/features/agents/presentation/widgets/agent_row.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/members/application/open_dm_use_case.dart';
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
    // the page build tree. activityLogs is consumed in AgentDetailBody
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
      return AgentDetailScaffold(
        agent: agent,
        isLoading: state.status == AgentsStatus.loading ||
            state.status == AgentsStatus.initial,
        isFailure: state.status == AgentsStatus.failure,
        failureMessage: state.failure?.userMessage(context.l10n),
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
        AgentsStatus.failure => AgentsFailureView(
            message: state.failure?.userMessage(context.l10n) ??
                context.l10n.errorUnknown,
            onRetry: ref.read(agentsStoreProvider.notifier).retry,
          ),
        AgentsStatus.success when state.items.isEmpty => EmptyStateWidget(
            key: const ValueKey('agents-empty'),
            icon: Icons.smart_toy_outlined,
            title: context.l10n.agentsEmptyTitle,
          ),
        AgentsStatus.success => _buildGroupedList(
            state.items,
            colors,
            ref.watch(agentStatusGroupProjectionProvider),
          ),
      },
    );
  }

  Widget _buildGroupedList(
    List<AgentItem> items,
    AppColors colors,
    // #653: ref.watch moved to build() — pass groups as parameter.
    List<AgentStatusGroup> groups,
  ) {
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
      showAppSnackBar(context, context.l10n.agentsSelectServerFirst);
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
      showAppSnackBar(context, context.l10n.agentsCreated);
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, failure.userMessage(context.l10n));
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
      showAppSnackBar(context, context.l10n.agentsUpdated);
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, failure.userMessage(context.l10n));
    }
  }

  Future<void> _deleteAgent(AgentItem agent) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(context.l10n.agentsDeleteTitle),
              content: Text(
                context.l10n.agentsDeleteMessage(agent.label),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(context.l10n.agentsActionCancel),
                ),
                FilledButton(
                  key: const ValueKey('agent-delete-confirm'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(context.l10n.agentsActionDelete),
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

      showAppSnackBar(context, context.l10n.agentsDeleted);

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
      showAppSnackBar(context, failure.userMessage(context.l10n));
    }
  }

  Future<void> _startAgent(AgentItem agent) async {
    try {
      await ref.read(agentsStoreProvider.notifier).startAgent(agent.id);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(context, failure.userMessage(context.l10n));
    } catch (_) {}
  }

  Future<void> _stopAgent(AgentItem agent) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(context.l10n.agentsStopTitle),
              content: Text(
                context.l10n.agentsStopMessage(agent.label),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(context.l10n.agentsActionCancel),
                ),
                FilledButton(
                  key: const ValueKey('agent-stop-confirm'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(context.l10n.agentsActionStop),
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
      showAppSnackBar(context, failure.userMessage(context.l10n));
    } catch (_) {}
  }

  Future<void> _resetAgent(AgentItem agent) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(context.l10n.agentsResetTitle),
              content: Text(
                context.l10n.agentsResetMessage(agent.label),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(context.l10n.agentsActionCancel),
                ),
                FilledButton(
                  key: const ValueKey('agent-reset-confirm'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(context.l10n.agentsActionReset),
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
      showAppSnackBar(context, context.l10n.agentsResetSuccess);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(context, failure.userMessage(context.l10n));
    }
  }

  Future<void> _messageAgent(AgentItem agent) async {
    final serverId = _resolvedServerId();
    if (serverId == null) {
      showAppSnackBar(context, context.l10n.agentsSelectServerFirst);
      return;
    }
    try {
      final channelId = await ref.read(openAgentDmUseCaseProvider)(
        ServerScopeId(serverId),
        agentId: agent.id,
      );
      if (!mounted) return;
      context.push('/servers/$serverId/dms/$channelId');
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(context, failure.userMessage(context.l10n));
    } catch (_) {}
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
        context.l10n.agentsSummary(activeCount, stoppedCount),
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
            AgentRow(
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
    final l10n = context.l10n;
    final statusLabel = displayStatusLabel(group.displayStatus, l10n: l10n);
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

    return Semantics(
      button: true,
      expanded: !isCollapsed,
      label: l10n.agentsStatusGroupSemantics(statusLabel, group.count),
      child: InkWell(
        key: ValueKey(
          'status-header-${group.foldKey}',
        ),
        onTap: onToggle,
        child: ExcludeSemantics(
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
                    statusLabel,
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
