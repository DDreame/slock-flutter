import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_status_tokens.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_realtime_binding.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Agents')),
      floatingActionButton: state.status == AgentsStatus.success
          ? FloatingActionButton.extended(
              key: const ValueKey('agents-create-fab'),
              onPressed: state.isCreating ? null : _createAgent,
              icon: state.isCreating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Create Agent'),
            )
          : null,
      body: switch (state.status) {
        AgentsStatus.initial || AgentsStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        AgentsStatus.failure => _AgentsFailureView(
            message: state.failure?.message ?? 'Failed to load agents.',
            onRetry: ref.read(agentsStoreProvider.notifier).retry,
          ),
        AgentsStatus.success when state.items.isEmpty => const Center(
            child: Text('No agents yet.'),
          ),
        AgentsStatus.success => _AgentsListView(
            items: state.items,
            onTap: _openAgentDetail,
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
      context.go('/servers/$serverId/dms/$channelId');
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

class _AgentsListView extends StatelessWidget {
  const _AgentsListView({
    required this.items,
    required this.onTap,
    required this.onStart,
    required this.onStop,
    required this.onReset,
  });

  final List<AgentItem> items;
  final void Function(AgentItem) onTap;
  final Future<void> Function(AgentItem) onStart;
  final Future<void> Function(AgentItem) onStop;
  final Future<void> Function(AgentItem) onReset;

  @override
  Widget build(BuildContext context) {
    final active = items.where((a) => a.isActive).toList();
    final stopped = items.where((a) => !a.isActive).toList();

    return ListView(
      key: const ValueKey('agents-list'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        if (active.isNotEmpty) ...[
          _AgentSectionHeader(title: 'Active (${active.length})'),
          for (final agent in active)
            _AgentCard(
              agent: agent,
              onTap: onTap,
              onStart: onStart,
              onStop: onStop,
              onReset: onReset,
            ),
        ],
        if (stopped.isNotEmpty) ...[
          _AgentSectionHeader(title: 'Stopped (${stopped.length})'),
          for (final agent in stopped)
            _AgentCard(
              agent: agent,
              onTap: onTap,
              onStart: onStart,
              onStop: onStop,
              onReset: onReset,
            ),
        ],
      ],
    );
  }
}

class _AgentSectionHeader extends StatelessWidget {
  const _AgentSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.onTap,
    required this.onStart,
    required this.onStop,
    required this.onReset,
  });

  final AgentItem agent;
  final void Function(AgentItem) onTap;
  final Future<void> Function(AgentItem) onStart;
  final Future<void> Function(AgentItem) onStop;
  final Future<void> Function(AgentItem) onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('agent-${agent.id}'),
      onTap: () => onTap(agent),
      onLongPress: () => _showAgentActions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _ActivityDot(
              dotKey: ValueKey('agent-activity-${agent.id}'),
              activity: agent.activity,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agent.label, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    _activityLabel(agent.activity, agent.activityDetail),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              agent.runtime,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
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

class _ActivityDot extends StatelessWidget {
  const _ActivityDot({required this.activity, this.dotKey});

  final String activity;
  final Key? dotKey;

  @override
  Widget build(BuildContext context) {
    final tone = switch (activity) {
      'online' => AppStatusTone.success,
      'thinking' => AppStatusTone.warning,
      'working' => AppStatusTone.info,
      'error' => AppStatusTone.error,
      'offline' => AppStatusTone.neutral,
      _ => AppStatusTone.neutral,
    };
    final color =
        appStatusColors(Theme.of(context).colorScheme, tone).foreground;
    return Container(
      key: dotKey,
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

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

class _AgentDetailBody extends StatefulWidget {
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
  State<_AgentDetailBody> createState() => _AgentDetailBodyState();
}

class _AgentDetailBodyState extends State<_AgentDetailBody> {
  List<AgentActivityLogEntry>? _activityLog;
  bool _logLoading = false;

  @override
  void initState() {
    super.initState();
    _loadActivityLog();
  }

  Future<void> _loadActivityLog() async {
    setState(() => _logLoading = true);
    try {
      final container = ProviderScope.containerOf(context);
      final repo = container.read(agentsRepositoryProvider);
      final log = await repo.getActivityLog(widget.agent.id);
      if (mounted) {
        setState(() {
          _activityLog = log;
          _logLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _logLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agent = widget.agent;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _ActivityDot(
              dotKey: ValueKey('agent-activity-${agent.id}'),
              activity: agent.activity,
            ),
            const SizedBox(width: 8),
            Text(
              _activityLabel(agent.activity, agent.activityDetail),
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (agent.description != null && agent.description!.isNotEmpty) ...[
          Text(agent.description!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
        ],
        _DetailRow(label: 'Model', value: agent.model),
        _DetailRow(label: 'Runtime', value: agent.runtime),
        if (agent.reasoningEffort != null)
          _DetailRow(label: 'Reasoning', value: agent.reasoningEffort!),
        if (agent.machineId != null)
          _DetailRow(label: 'Machine', value: agent.machineId!),
        _DetailRow(label: 'Status', value: agent.status),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('agent-message-btn'),
              onPressed: widget.onMessage == null
                  ? null
                  : () => widget.onMessage!(agent),
              icon: const Icon(Icons.message_outlined),
              label: const Text('Message'),
            ),
            if (agent.isStopped)
              FilledButton.icon(
                key: const ValueKey('agent-start-btn'),
                onPressed: widget.onStart == null
                    ? null
                    : () => widget.onStart!(agent),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
            if (agent.isActive)
              FilledButton.icon(
                key: const ValueKey('agent-stop-btn'),
                onPressed:
                    widget.onStop == null ? null : () => widget.onStop!(agent),
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            if (agent.isActive)
              OutlinedButton.icon(
                key: const ValueKey('agent-reset-btn'),
                onPressed: widget.onReset == null
                    ? null
                    : () => widget.onReset!(agent),
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Activity Log', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_logLoading)
          const Center(child: CircularProgressIndicator())
        else if (_activityLog == null || _activityLog!.isEmpty)
          const Text('No activity log entries.')
        else
          for (final entry in _activityLog!)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTime(entry.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(entry.entry, style: theme.textTheme.bodySmall),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _AgentsFailureView extends StatelessWidget {
  const _AgentsFailureView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

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
