import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/role_badge.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/app/widgets/status_glow_ring.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_realtime_binding.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/presentation/widget/agent_form_dialog.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';

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
    Future.microtask(() => ref.read(agentsStoreProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(agentsRealtimeBindingProvider);
    final state = ref.watch(agentsStoreProvider);

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
        onEdit: agent == null || state.isBusy(agent.id) ? null : _editAgent,
        onDelete: agent == null || state.isBusy(agent.id) ? null : _deleteAgent,
        onStart: agent == null || state.isBusy(agent.id) ? null : _startAgent,
        onStop: agent == null || state.isBusy(agent.id) ? null : _stopAgent,
        onReset: agent == null || state.isBusy(agent.id) ? null : _resetAgent,
        onMessage:
            agent == null || state.isBusy(agent.id) ? null : _messageAgent,
      );
    }

    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      body: switch (state.status) {
        AgentsStatus.initial || AgentsStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        AgentsStatus.failure => _AgentsFailureView(
            message: state.failure?.message ?? 'Failed to load agents.',
            onRetry: ref.read(agentsStoreProvider.notifier).retry,
          ),
        AgentsStatus.success when state.items.isEmpty => SafeArea(
            child: Column(
              children: [
                _AgentsHeader(
                  colors: colors,
                  onNew: _createAgent,
                  isCreating: state.isCreating,
                ),
                const Expanded(
                  child: Center(child: Text('No agents yet.')),
                ),
              ],
            ),
          ),
        AgentsStatus.success => _AgentsListView(
            items: state.items,
            colors: colors,
            onTap: _openAgentDetail,
            onNew: state.isCreating ? null : _createAgent,
            isCreating: state.isCreating,
            onStart: _startAgent,
            onStop: _stopAgent,
            onReset: _resetAgent,
          ),
      },
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
      _showSnackBar('Select a server first.');
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
      _showSnackBar('Agent created.');
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showSnackBar(failure.message ?? 'Failed to create agent.');
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
      _showSnackBar('Agent updated.');
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _showSnackBar(failure.message ?? 'Failed to update agent.');
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

      _showSnackBar('Agent deleted.');

      if (widget.agentId != null) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
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
      _showSnackBar(failure.message ?? 'Failed to delete agent.');
    }
  }

  Future<void> _startAgent(AgentItem agent) async {
    try {
      await ref.read(agentsStoreProvider.notifier).startAgent(agent.id);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      _showSnackBar(failure.message ?? 'Failed to start agent.');
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
      _showSnackBar(failure.message ?? 'Failed to stop agent.');
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
      _showSnackBar('Agent reset.');
    } on AppFailure catch (failure) {
      if (!mounted) return;
      _showSnackBar(failure.message ?? 'Failed to reset agent.');
    }
  }

  Future<void> _messageAgent(AgentItem agent) async {
    final serverId = _resolvedServerId();
    if (serverId == null) {
      _showSnackBar('Select a server first.');
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
      _showSnackBar(failure.message ?? 'Failed to open conversation.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _AgentsHeader extends StatelessWidget {
  const _AgentsHeader({
    required this.colors,
    required this.onNew,
    required this.isCreating,
  });

  final AppColors colors;
  final VoidCallback? onNew;
  final bool isCreating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text('Agents',
              style: AppTypography.displayMedium.copyWith(
                color: colors.text,
              )),
          const Spacer(),
          FilledButton(
            key: const ValueKey('agents-new-btn'),
            onPressed: isCreating ? null : onNew,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryForeground,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
            ),
            child: isCreating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('New'),
          ),
        ],
      ),
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
// List view
// ---------------------------------------------------------------------------

class _AgentsListView extends StatelessWidget {
  const _AgentsListView({
    required this.items,
    required this.colors,
    required this.onTap,
    required this.onNew,
    required this.isCreating,
    required this.onStart,
    required this.onStop,
    required this.onReset,
  });

  final List<AgentItem> items;
  final AppColors colors;
  final void Function(AgentItem) onTap;
  final VoidCallback? onNew;
  final bool isCreating;
  final Future<void> Function(AgentItem) onStart;
  final Future<void> Function(AgentItem) onStop;
  final Future<void> Function(AgentItem) onReset;

  @override
  Widget build(BuildContext context) {
    final active = items.where((a) => a.isActive).toList();
    final stopped = items.where((a) => !a.isActive).toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AgentsHeader(
            colors: colors,
            onNew: onNew,
            isCreating: isCreating,
          ),
          _AgentsStatsSummary(
            activeCount: active.length,
            stoppedCount: stopped.length,
            colors: colors,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView(
              key: const ValueKey('agents-list'),
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionLabel(title: 'Active', colors: colors),
                  for (final agent in active)
                    _AgentRow(
                      agent: agent,
                      colors: colors,
                      onTap: onTap,
                      onStart: onStart,
                      onStop: onStop,
                      onReset: onReset,
                    ),
                ],
                if (stopped.isNotEmpty) ...[
                  _SectionLabel(title: 'Stopped', colors: colors),
                  for (final agent in stopped)
                    _AgentRow(
                      agent: agent,
                      colors: colors,
                      onTap: onTap,
                      onStart: onStart,
                      onStop: onStop,
                      onReset: onReset,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.colors});

  final String title;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: AppTypography.label.copyWith(
          color: colors.textTertiary,
          fontWeight: FontWeight.w600,
        ),
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

  void _showAgentActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (agent.isStopped)
                ListTile(
                  leading: const Icon(Icons.play_arrow),
                  title: const Text('Start'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onStart(agent);
                  },
                ),
              if (agent.isActive)
                ListTile(
                  leading: const Icon(Icons.stop),
                  title: const Text('Stop'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onStop(agent);
                  },
                ),
              if (agent.isActive)
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Reset Session'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onReset(agent);
                  },
                ),
            ],
          ),
        );
      },
    );
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
            ? const Center(child: CircularProgressIndicator())
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
            IconButton(
              key: const ValueKey('agent-env-vars-edit'),
              onPressed: () {
                // TODO: wire to env vars editor when API is available.
              },
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: colors.textSecondary,
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
