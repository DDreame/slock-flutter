import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_status_tokens.dart';
import 'package:slock_app/app/theme/app_typography.dart';
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
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      body: switch (state.status) {
        TasksStatus.initial ||
        TasksStatus.loading when state.items.isEmpty =>
          const Center(child: CircularProgressIndicator()),
        TasksStatus.loading => _TasksListSurface(
            items: state.items,
            colors: colors,
            isRefreshing: true,
            onStatusUpdate: _updateStatus,
            onDelete: _deleteTask,
            onClaim: _claimTask,
            onUnclaim: _unclaimTask,
            onNew: _showCreateTaskDialog,
          ),
        TasksStatus.initial || TasksStatus.failure => _TasksFailureView(
            message: state.failure?.message ?? 'Failed to load tasks.',
            onRetry: ref.read(tasksStoreProvider.notifier).retry,
          ),
        TasksStatus.success when state.items.isEmpty => SafeArea(
            child: Column(
              children: [
                _TasksHeader(colors: colors, onNew: _showCreateTaskDialog),
                const Expanded(
                  child: Center(child: Text('No tasks yet.')),
                ),
              ],
            ),
          ),
        TasksStatus.success => _TasksListSurface(
            items: state.items,
            colors: colors,
            onStatusUpdate: _updateStatus,
            onDelete: _deleteTask,
            onClaim: _claimTask,
            onUnclaim: _unclaimTask,
            onNew: _showCreateTaskDialog,
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
            final colorScheme = Theme.of(dialogContext).colorScheme;
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
                  style: appDestructiveFilledButtonStyle(colorScheme),
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

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _TasksHeader extends StatelessWidget {
  const _TasksHeader({required this.colors, required this.onNew});

  final AppColors colors;
  final VoidCallback onNew;

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
          Text(
            'Tasks',
            style: AppTypography.displayMedium.copyWith(color: colors.text),
          ),
          const Spacer(),
          FilledButton(
            key: const ValueKey('tasks-new-btn'),
            onPressed: onNew,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryForeground,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
            ),
            child: const Text('New'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary header
// ---------------------------------------------------------------------------

class _TasksSummaryHeader extends StatelessWidget {
  const _TasksSummaryHeader({required this.items, required this.colors});

  final List<TaskItem> items;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    int count(String status) => items.where((t) => t.status == status).length;

    final todoCount = count('todo');
    final progressCount = count('in_progress');
    final reviewCount = count('in_review');
    final doneCount = count('done');

    return Padding(
      key: const ValueKey('tasks-summary-header'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Row(
        children: [
          _SummaryChip(
            symbol: '○',
            count: todoCount,
            label: 'To Do',
            color: colors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.lg),
          _SummaryChip(
            symbol: '◐',
            count: progressCount,
            label: 'In Progress',
            color: colors.primary,
          ),
          const SizedBox(width: AppSpacing.lg),
          _SummaryChip(
            symbol: '◑',
            count: reviewCount,
            label: 'Review',
            color: colors.warning,
          ),
          const SizedBox(width: AppSpacing.lg),
          _SummaryChip(
            symbol: '●',
            count: doneCount,
            label: 'Done',
            color: colors.success,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.symbol,
    required this.count,
    required this.label,
    required this.color,
  });

  final String symbol;
  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: AppTypography.title.copyWith(color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// List surface
// ---------------------------------------------------------------------------

class _TasksListSurface extends StatelessWidget {
  const _TasksListSurface({
    required this.items,
    required this.colors,
    required this.onStatusUpdate,
    required this.onDelete,
    required this.onClaim,
    required this.onUnclaim,
    required this.onNew,
    this.isRefreshing = false,
  });

  final List<TaskItem> items;
  final AppColors colors;
  final Future<void> Function(TaskItem, String) onStatusUpdate;
  final Future<void> Function(TaskItem) onDelete;
  final Future<void> Function(TaskItem) onClaim;
  final Future<void> Function(TaskItem) onUnclaim;
  final VoidCallback onNew;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TasksHeader(colors: colors, onNew: onNew),
          _TasksSummaryHeader(items: items, colors: colors),
          const SizedBox(height: AppSpacing.md),
          if (isRefreshing)
            const LinearProgressIndicator(
              key: ValueKey('tasks-refresh-indicator'),
            ),
          Expanded(
            child: _TasksListView(
              items: items,
              colors: colors,
              onStatusUpdate: onStatusUpdate,
              onDelete: onDelete,
              onClaim: onClaim,
              onUnclaim: onUnclaim,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List view
// ---------------------------------------------------------------------------

class _TasksListView extends StatelessWidget {
  const _TasksListView({
    required this.items,
    required this.colors,
    required this.onStatusUpdate,
    required this.onDelete,
    required this.onClaim,
    required this.onUnclaim,
  });

  final List<TaskItem> items;
  final AppColors colors;
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
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        for (final status in statusOrder)
          if (grouped[status] != null && grouped[status]!.isNotEmpty) ...[
            _TaskSectionLabel(status: status, colors: colors),
            for (final task in grouped[status]!)
              _TaskRow(
                task: task,
                colors: colors,
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

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _TaskSectionLabel extends StatelessWidget {
  const _TaskSectionLabel({required this.status, required this.colors});

  final String status;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('task-section-$status'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        AppSpacing.xs,
      ),
      child: Text(
        _statusLabel(status),
        style: AppTypography.label.copyWith(
          color: colors.textTertiary,
          fontWeight: FontWeight.w600,
        ),
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

// ---------------------------------------------------------------------------
// Status symbol helpers
// ---------------------------------------------------------------------------

/// Returns the Z3 status symbol for a given task status.
String _statusSymbol(String status) {
  return switch (status) {
    'todo' => '○',
    'in_progress' => '◐',
    'in_review' => '◑',
    'done' => '●',
    _ => '○',
  };
}

/// Returns the color for a status symbol using [AppColors] tokens.
Color _statusColor(String status, AppColors colors) {
  return switch (status) {
    'todo' => colors.textTertiary,
    'in_progress' => colors.primary,
    'in_review' => colors.warning,
    'done' => colors.success,
    _ => colors.textTertiary,
  };
}

// ---------------------------------------------------------------------------
// Task row
// ---------------------------------------------------------------------------

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.colors,
    required this.onStatusUpdate,
    required this.onDelete,
    required this.onClaim,
    required this.onUnclaim,
  });

  final TaskItem task;
  final AppColors colors;
  final Future<void> Function(TaskItem, String) onStatusUpdate;
  final Future<void> Function(TaskItem) onDelete;
  final Future<void> Function(TaskItem) onClaim;
  final Future<void> Function(TaskItem) onUnclaim;

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 'done';

    Widget row = InkWell(
      key: ValueKey('task-${task.id}'),
      onTap: () => _onPrimaryTap(context),
      onLongPress: () => _showTaskActions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Status symbol
            Text(
              _statusSymbol(task.status),
              style: AppTypography.title.copyWith(
                color: _statusColor(task.status, colors),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Task number + title
            Expanded(
              child: Text(
                '#${task.taskNumber} ${task.title}',
                style: AppTypography.body.copyWith(
                  color: colors.text,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Assignee avatar
            if (task.claimedByName != null) ...[
              const SizedBox(width: AppSpacing.sm),
              CircleAvatar(
                key: ValueKey('task-assignee-${task.id}'),
                radius: 14,
                backgroundColor: colors.surfaceAlt,
                child: Text(
                  task.claimedByName!.isNotEmpty
                      ? task.claimedByName![0].toUpperCase()
                      : '?',
                  style: AppTypography.caption.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isDone) {
      row = Opacity(
        key: ValueKey('task-row-opacity-${task.id}'),
        opacity: 0.5,
        child: row,
      );
    }

    return row;
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
    final theme = Theme.of(context);
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
}

// ---------------------------------------------------------------------------
// Failure view
// ---------------------------------------------------------------------------

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
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
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

// ---------------------------------------------------------------------------
// Create task dialog
// ---------------------------------------------------------------------------

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
          const SizedBox(height: AppSpacing.md),
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
