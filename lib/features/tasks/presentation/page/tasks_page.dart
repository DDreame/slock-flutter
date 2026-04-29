import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/tasks/application/tasks_realtime_binding.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key, required this.serverId});

  final String serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentTasksServerIdProvider.overrideWithValue(ServerScopeId(serverId)),
      ],
      child: const _TasksScreen(),
    );
  }
}

class _TasksScreen extends ConsumerStatefulWidget {
  const _TasksScreen();

  @override
  ConsumerState<_TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<_TasksScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(tasksStoreProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(tasksRealtimeBindingProvider);
    final state = ref.watch(tasksStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton:
          state.items.isNotEmpty || state.status == TasksStatus.success
              ? FloatingActionButton(
                  key: const ValueKey('tasks-create-fab'),
                  onPressed: _showCreateTaskDialog,
                  child: const Icon(Icons.add),
                )
              : null,
      body: switch (state.status) {
        TasksStatus.initial ||
        TasksStatus.loading when state.items.isEmpty =>
          const Center(child: CircularProgressIndicator()),
        TasksStatus.loading => _TasksListSurface(
            items: state.items,
            isRefreshing: true,
            onStatusUpdate: _updateStatus,
            onDelete: _deleteTask,
            onClaim: _claimTask,
            onUnclaim: _unclaimTask,
          ),
        TasksStatus.initial || TasksStatus.failure => _TasksFailureView(
            message: state.failure?.message ?? 'Failed to load tasks.',
            onRetry: ref.read(tasksStoreProvider.notifier).retry,
          ),
        TasksStatus.success when state.items.isEmpty => const Center(
            child: Text('No tasks yet.'),
          ),
        TasksStatus.success => _TasksListSurface(
            items: state.items,
            onStatusUpdate: _updateStatus,
            onDelete: _deleteTask,
            onClaim: _claimTask,
            onUnclaim: _unclaimTask,
          ),
      },
    );
  }

  Future<void> _showCreateTaskDialog() async {
    final homeState = ref.read(homeListStoreProvider);
    final channels = homeState.channels;
    if (channels.isEmpty) {
      _showSnackBar('No channels available.');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _CreateTaskDialog(
          channels: channels,
          onCreate: (channelId, title) async {
            try {
              await ref.read(tasksStoreProvider.notifier).createTasks(
                channelId: channelId,
                titles: [title],
              );
              if (!mounted) return;
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              _showSnackBar('Task created.');
            } on AppFailure catch (failure) {
              if (!mounted) return;
              _showSnackBar(failure.message ?? 'Failed to create task.');
            }
          },
        );
      },
    );
  }

  Future<void> _updateStatus(TaskItem task, String newStatus) async {
    try {
      await ref.read(tasksStoreProvider.notifier).updateTaskStatus(
            taskId: task.id,
            status: newStatus,
          );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      _showSnackBar(failure.message ?? 'Failed to update task.');
    }
  }

  Future<void> _deleteTask(TaskItem task) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete Task?'),
              content: Text(
                'Delete "${task.title}"? This cannot be undone.',
              ),
              actions: [
                TextButton(
                  key: const ValueKey('task-delete-cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('task-delete-confirm'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      await ref.read(tasksStoreProvider.notifier).deleteTask(task.id);
      if (!mounted) return;
      _showSnackBar('Task deleted.');
    } on AppFailure catch (failure) {
      if (!mounted) return;
      _showSnackBar(failure.message ?? 'Failed to delete task.');
    }
  }

  Future<void> _claimTask(TaskItem task) async {
    try {
      await ref.read(tasksStoreProvider.notifier).claimTask(task.id);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      _showSnackBar(failure.message ?? 'Failed to claim task.');
    }
  }

  Future<void> _unclaimTask(TaskItem task) async {
    try {
      await ref.read(tasksStoreProvider.notifier).unclaimTask(task.id);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      _showSnackBar(failure.message ?? 'Failed to unclaim task.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TasksListSurface extends StatelessWidget {
  const _TasksListSurface({
    required this.items,
    required this.onStatusUpdate,
    required this.onDelete,
    required this.onClaim,
    required this.onUnclaim,
    this.isRefreshing = false,
  });

  final List<TaskItem> items;
  final Future<void> Function(TaskItem, String) onStatusUpdate;
  final Future<void> Function(TaskItem) onDelete;
  final Future<void> Function(TaskItem) onClaim;
  final Future<void> Function(TaskItem) onUnclaim;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _TasksListView(
          items: items,
          onStatusUpdate: onStatusUpdate,
          onDelete: onDelete,
          onClaim: onClaim,
          onUnclaim: onUnclaim,
        ),
        if (isRefreshing)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(
              key: ValueKey('tasks-refresh-indicator'),
            ),
          ),
      ],
    );
  }
}

class _TasksListView extends StatelessWidget {
  const _TasksListView({
    required this.items,
    required this.onStatusUpdate,
    required this.onDelete,
    required this.onClaim,
    required this.onUnclaim,
  });

  final List<TaskItem> items;
  final Future<void> Function(TaskItem, String) onStatusUpdate;
  final Future<void> Function(TaskItem) onDelete;
  final Future<void> Function(TaskItem) onClaim;
  final Future<void> Function(TaskItem) onUnclaim;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<TaskItem>>{};
    for (final item in items) {
      (grouped[item.status] ??= []).add(item);
    }

    const statusOrder = ['todo', 'in_progress', 'in_review', 'done'];

    return ListView(
      key: const ValueKey('tasks-list'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        for (final status in statusOrder)
          if (grouped[status] != null && grouped[status]!.isNotEmpty) ...[
            _TaskStatusHeader(status: status),
            for (final task in grouped[status]!)
              _TaskCard(
                task: task,
                onStatusUpdate: onStatusUpdate,
                onDelete: onDelete,
                onClaim: onClaim,
                onUnclaim: onUnclaim,
              ),
          ],
      ],
    );
  }
}

class _TaskStatusHeader extends StatelessWidget {
  const _TaskStatusHeader({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        _statusLabel(status),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'todo' => 'To Do',
      'in_progress' => 'In Progress',
      'in_review' => 'In Review',
      'done' => 'Done',
      _ => status,
    };
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onStatusUpdate,
    required this.onDelete,
    required this.onClaim,
    required this.onUnclaim,
  });

  final TaskItem task;
  final Future<void> Function(TaskItem, String) onStatusUpdate;
  final Future<void> Function(TaskItem) onDelete;
  final Future<void> Function(TaskItem) onClaim;
  final Future<void> Function(TaskItem) onUnclaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('task-${task.id}'),
      onTap: () => _onPrimaryTap(context),
      onLongPress: () => _showTaskActions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _StatusIcon(status: task.status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${task.taskNumber} ${task.title}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: task.status == 'done'
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (task.claimedByName != null)
                    Text(
                      task.claimedByName!,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPrimaryTap(BuildContext context) {
    final nextStatus = switch (task.status) {
      'todo' => 'in_progress',
      'in_progress' => 'in_review',
      'in_review' => 'done',
      _ => null,
    };
    if (nextStatus != null) {
      onStatusUpdate(task, nextStatus);
    } else {
      _showTaskActions(context);
    }
  }

  void _showTaskActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.status != 'done')
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Mark Done'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onStatusUpdate(task, 'done');
                  },
                ),
              if (task.status == 'todo')
                ListTile(
                  leading: const Icon(Icons.play_arrow),
                  title: const Text('Start'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onStatusUpdate(task, 'in_progress');
                  },
                ),
              if (task.status == 'in_progress')
                ListTile(
                  leading: const Icon(Icons.rate_review_outlined),
                  title: const Text('Move to Review'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onStatusUpdate(task, 'in_review');
                  },
                ),
              if (task.status == 'done')
                ListTile(
                  key: const ValueKey('task-action-reopen'),
                  leading: const Icon(Icons.replay),
                  title: const Text('Reopen'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onStatusUpdate(task, 'todo');
                  },
                ),
              if (task.status == 'in_review')
                ListTile(
                  key: const ValueKey('task-action-revert-in-progress'),
                  leading: const Icon(Icons.undo),
                  title: const Text('Revert to In Progress'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onStatusUpdate(task, 'in_progress');
                  },
                ),
              if (task.status == 'in_progress')
                ListTile(
                  key: const ValueKey('task-action-revert-todo'),
                  leading: const Icon(Icons.undo),
                  title: const Text('Revert to To Do'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onStatusUpdate(task, 'todo');
                  },
                ),
              if (task.claimedById == null)
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Claim'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onClaim(task);
                  },
                ),
              if (task.claimedById != null)
                ListTile(
                  leading: const Icon(Icons.person_remove),
                  title: const Text('Unclaim'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onUnclaim(task);
                  },
                ),
              if (!task.isLegacy)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Delete',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onDelete(task);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  ThemeData get theme => ThemeData();
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      'todo' => (Icons.radio_button_unchecked, Colors.grey),
      'in_progress' => (Icons.timelapse, Colors.blue),
      'in_review' => (Icons.rate_review, Colors.orange),
      'done' => (Icons.check_circle, Colors.green),
      _ => (Icons.circle_outlined, Colors.grey),
    };
    return Icon(icon, size: 20, color: color);
  }
}

class _TasksFailureView extends StatelessWidget {
  const _TasksFailureView({
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

class _CreateTaskDialog extends StatefulWidget {
  const _CreateTaskDialog({
    required this.channels,
    required this.onCreate,
  });

  final List<HomeChannelSummary> channels;
  final Future<void> Function(String channelId, String title) onCreate;

  @override
  State<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<_CreateTaskDialog> {
  final _titleController = TextEditingController();
  late String _selectedChannelId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedChannelId = widget.channels.first.scopeId.value;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('create-task-dialog'),
      title: const Text('Create Task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('task-channel-dropdown'),
            initialValue: _selectedChannelId,
            decoration: const InputDecoration(labelText: 'Channel'),
            items: [
              for (final channel in widget.channels)
                DropdownMenuItem(
                  value: channel.scopeId.value,
                  child: Text(channel.name),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedChannelId = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('task-title-field'),
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _isSubmitting = true);
    await widget.onCreate(_selectedChannelId, title);
    if (mounted) setState(() => _isSubmitting = false);
  }
}
