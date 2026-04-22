import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_realtime_binding.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';

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
      () => ref.read(agentsStoreProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(agentsRealtimeBindingProvider);
    final state = ref.watch(agentsStoreProvider);

    if (widget.agentId != null) {
      final agent =
          state.items.where((a) => a.id == widget.agentId).firstOrNull;
      return _AgentDetailScaffold(
        agent: agent,
        isLoading: state.status == AgentsStatus.loading ||
            state.status == AgentsStatus.initial,
        isFailure: state.status == AgentsStatus.failure,
        failureMessage: state.failure?.message,
        onRetry: ref.read(agentsStoreProvider.notifier).retry,
        onStart: _startAgent,
        onStop: _stopAgent,
        onReset: _resetAgent,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Agents')),
      body: switch (state.status) {
        AgentsStatus.initial ||
        AgentsStatus.loading =>
          const Center(child: CircularProgressIndicator()),
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AgentsPage(agentId: agent.id),
      ),
    );
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
    try {
      await ref.read(agentsStoreProvider.notifier).stopAgent(agent.id);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      _showSnackBar(failure.message ?? 'Failed to stop agent.');
    }
  }

  Future<void> _resetAgent(AgentItem agent) async {
    try {
      await ref.read(agentsStoreProvider.notifier).resetAgent(agent.id);
      if (!mounted) return;
      _showSnackBar('Agent reset.');
    } on AppFailure catch (failure) {
      if (!mounted) return;
      _showSnackBar(failure.message ?? 'Failed to reset agent.');
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
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
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
            _ActivityDot(activity: agent.activity),
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
  const _ActivityDot({required this.activity});

  final String activity;

  @override
  Widget build(BuildContext context) {
    final color = switch (activity) {
      'online' => Colors.green,
      'thinking' => Colors.amber,
      'working' => Colors.blue,
      'error' => Colors.red,
      'offline' => Colors.grey,
      _ => Colors.grey,
    };
    return Container(
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
    required this.onStart,
    required this.onStop,
    required this.onReset,
  });

  final AgentItem? agent;
  final bool isLoading;
  final bool isFailure;
  final String? failureMessage;
  final VoidCallback onRetry;
  final Future<void> Function(AgentItem) onStart;
  final Future<void> Function(AgentItem) onStop;
  final Future<void> Function(AgentItem) onReset;

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
      appBar: AppBar(title: Text(a.label)),
      body: _AgentDetailBody(
        agent: a,
        onStart: onStart,
        onStop: onStop,
        onReset: onReset,
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
  });

  final AgentItem agent;
  final Future<void> Function(AgentItem) onStart;
  final Future<void> Function(AgentItem) onStop;
  final Future<void> Function(AgentItem) onReset;

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
            _ActivityDot(activity: agent.activity),
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
            if (agent.isStopped)
              FilledButton.icon(
                key: const ValueKey('agent-start-btn'),
                onPressed: () => widget.onStart(agent),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
            if (agent.isActive)
              FilledButton.icon(
                key: const ValueKey('agent-stop-btn'),
                onPressed: () => widget.onStop(agent),
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            if (agent.isActive)
              OutlinedButton.icon(
                key: const ValueKey('agent-reset-btn'),
                onPressed: () => widget.onReset(agent),
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
                    child: Text(
                      entry.entry,
                      style: theme.textTheme.bodySmall,
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
  const _AgentsFailureView({
    required this.message,
    required this.onRetry,
  });

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
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
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
