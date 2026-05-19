import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_status_tokens.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/list_action_sheet.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
import 'package:slock_app/app/widgets/swipe_action_wrapper.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/presentation/widget/task_status_overlay.dart';
import 'package:slock_app/l10n/l10n.dart';

// -- Filter chip Z2 spec tokens --
const double _kFilterChipHeight = 32.0;
const double _kFilterChipRadius = 16.0;
const double _kFilterChipHorizontalPadding = 14.0;
const double _kFilterChipFontSize = 13.0;
const FontWeight _kFilterChipFontWeight = FontWeight.w500;
const double _kFilterChipGap = 8.0;

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
      () => ref.read(tasksStoreProvider.notifier).ensureLoaded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to task events relayed by the root event router.
    // Replaces the old tasksRealtimeBindingProvider.
    ref.listen(routedTaskEventProvider, (prev, next) {
      if (next == null) return;
      try {
        final store = ref.read(tasksStoreProvider.notifier);
        switch (next) {
          case TasksCreatedRouterEvent(:final tasks):
            for (final task in tasks) {
              store.upsertTask(task);
            }
          case TaskUpdatedRouterEvent(:final task):
            store.upsertTask(task);
          case TaskDeletedRouterEvent(:final taskId):
            store.removeTask(taskId);
        }
      } catch (e, st) {
        ref.read(crashReporterProvider).captureException(e, stackTrace: st);
      }
    });

    final state = ref.watch(tasksStoreProvider);
    // INV-NET-DEGRADE-2: surface refresh failure via snackbar only when a
    // refresh completes with failure — not on mutation errors.
    ref.listen(
      tasksStoreProvider.select((s) => s.isRefreshing),
      (prev, next) {
        if (prev == true && next == false) {
          final s = ref.read(tasksStoreProvider);
          if (s.failure != null && s.status == TasksStatus.success) {
            _showRefreshFailedSnackBar();
          }
        }
      },
    );
    final colors = Theme.of(context).extension<AppColors>()!;
    final homeSnap = ref.watch(
      homeListStoreProvider
          .select((s) => (status: s.status, channels: s.channels)),
    );
    final channels = homeSnap.status == HomeListStatus.success
        ? homeSnap.channels
        : const <HomeChannelSummary>[];

    return Scaffold(
      body: switch (state.status) {
        TasksStatus.initial ||
        TasksStatus.loading when state.items.isEmpty =>
          ListView(
            key: const ValueKey('tasks-skeleton'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.sm,
            ),
            children: const [
              SkeletonListItem(key: ValueKey('tasks-skeleton-item-0')),
              SkeletonListItem(key: ValueKey('tasks-skeleton-item-1')),
              SkeletonListItem(key: ValueKey('tasks-skeleton-item-2')),
              SkeletonListItem(key: ValueKey('tasks-skeleton-item-3')),
              SkeletonListItem(key: ValueKey('tasks-skeleton-item-4')),
            ],
          ),
        TasksStatus.loading => _TasksListSurface(
            items: state.items,
            colors: colors,
            isRefreshing: true,
            onStatusUpdate: _updateStatus,
            onDelete: _deleteTask,
            onClaim: _claimTask,
            onUnclaim: _unclaimTask,
            onNew: _showCreateTaskDialog,
            channels: channels,
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
            channels: channels,
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
      HapticFeedback.errorNotification();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(failure.message ?? 'Failed to update task.'),
          action: SnackBarAction(
            label: 'RETRY',
            onPressed: () => _updateStatus(task, newStatus),
          ),
        ));
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

  void _showRefreshFailedSnackBar() {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.refreshFailedSnackbar),
        action: SnackBarAction(
          label: l10n.refreshFailedRetry,
          onPressed: () => ref.read(tasksStoreProvider.notifier).load(),
        ),
      ));
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
    final closedCount = count('closed');

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
          const SizedBox(width: AppSpacing.lg),
          _SummaryChip(
            symbol: '✕',
            count: closedCount,
            label: 'Closed',
            color: colors.textTertiary,
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

class _TasksListSurface extends StatefulWidget {
  const _TasksListSurface({
    required this.items,
    required this.colors,
    required this.onStatusUpdate,
    required this.onDelete,
    required this.onClaim,
    required this.onUnclaim,
    required this.onNew,
    this.isRefreshing = false,
    this.channels = const [],
  });

  final List<TaskItem> items;
  final AppColors colors;
  final Future<void> Function(TaskItem, String) onStatusUpdate;
  final Future<void> Function(TaskItem) onDelete;
  final Future<void> Function(TaskItem) onClaim;
  final Future<void> Function(TaskItem) onUnclaim;
  final VoidCallback onNew;
  final bool isRefreshing;
  final List<HomeChannelSummary> channels;

  @override
  State<_TasksListSurface> createState() => _TasksListSurfaceState();
}

class _TasksListSurfaceState extends State<_TasksListSurface> {
  String? _selectedChannelId; // null = All

  /// Build the ordered list of channel IDs for filter chips.
  ///
  /// Includes all channels from the home list (the server's channel set)
  /// that either have tasks or are available for filtering.
  List<String> _filterChannelIds() {
    // Start with channels that have tasks (preserving discovery order)
    final seen = <String>{};
    final ids = <String>[];
    for (final item in widget.items) {
      if (seen.add(item.channelId)) {
        ids.add(item.channelId);
      }
    }
    // Append any server channels not yet in the list
    for (final ch in widget.channels) {
      if (seen.add(ch.scopeId.value)) {
        ids.add(ch.scopeId.value);
      }
    }
    return ids;
  }

  /// Resolve a channel ID to its display name.
  String _channelName(String channelId) {
    for (final ch in widget.channels) {
      if (ch.scopeId.value == channelId) return ch.name;
    }
    return channelId;
  }

  List<TaskItem> get _filteredItems {
    if (_selectedChannelId == null) return widget.items;
    return widget.items
        .where((t) => t.channelId == _selectedChannelId)
        .toList();
  }

  bool get _showFilterBar {
    return _filterChannelIds().length > 1;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TasksHeader(colors: widget.colors, onNew: widget.onNew),
          _TasksSummaryHeader(items: filteredItems, colors: widget.colors),
          const SizedBox(height: AppSpacing.md),
          if (_showFilterBar)
            _TasksChannelFilterBar(
              channelIds: _filterChannelIds(),
              channelName: _channelName,
              selectedChannelId: _selectedChannelId,
              colors: widget.colors,
              onSelected: (id) => setState(() => _selectedChannelId = id),
            ),
          if (widget.isRefreshing)
            const LinearProgressIndicator(
              key: ValueKey('tasks-refresh-indicator'),
            ),
          if (filteredItems.isEmpty && _selectedChannelId != null)
            const Expanded(
              child: Center(
                child: Text('No tasks in this channel.'),
              ),
            )
          else
            Expanded(
              child: _TasksListView(
                items: filteredItems,
                colors: widget.colors,
                onStatusUpdate: widget.onStatusUpdate,
                onDelete: widget.onDelete,
                onClaim: widget.onClaim,
                onUnclaim: widget.onUnclaim,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Channel filter bar
// ---------------------------------------------------------------------------

class _TasksChannelFilterBar extends StatelessWidget {
  const _TasksChannelFilterBar({
    required this.channelIds,
    required this.channelName,
    required this.selectedChannelId,
    required this.colors,
    required this.onSelected,
  });

  final List<String> channelIds;
  final String Function(String) channelName;
  final String? selectedChannelId;
  final AppColors colors;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('task-filter-bar'),
      padding: const EdgeInsets.only(
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
        bottom: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              key: const ValueKey('task-filter-all'),
              label: '全部',
              isSelected: selectedChannelId == null,
              colors: colors,
              onTap: () => onSelected(null),
            ),
            for (final id in channelIds) ...[
              const SizedBox(width: _kFilterChipGap),
              _FilterChip(
                key: ValueKey('task-filter-$id'),
                label: channelName(id),
                isSelected: selectedChannelId == id,
                colors: colors,
                onTap: () => onSelected(id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: _kFilterChipHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: _kFilterChipHorizontalPadding,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : colors.surfaceAlt,
            borderRadius: BorderRadius.circular(_kFilterChipRadius),
            border: isSelected ? null : Border.all(color: colors.border),
          ),
          alignment: Alignment.center,
          child: ExcludeSemantics(
            child: Text(
              label,
              style: TextStyle(
                fontSize: _kFilterChipFontSize,
                fontWeight: _kFilterChipFontWeight,
                color: isSelected
                    ? colors.primaryForeground
                    : colors.textSecondary,
              ),
            ),
          ),
        ),
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
    // Flatten tasks into an indexed list of header + task items.
    final flatItems = <_FlatListItem>[];
    final grouped = <String, List<TaskItem>>{};
    for (final item in items) {
      (grouped[item.status] ??= []).add(item);
    }

    const statusOrder = ['todo', 'in_progress', 'in_review', 'done', 'closed'];

    for (final status in statusOrder) {
      if (grouped[status] != null && grouped[status]!.isNotEmpty) {
        flatItems.add(_FlatHeaderItem(status));
        for (final task in grouped[status]!) {
          flatItems.add(_FlatTaskItem(task));
        }
      }
    }

    return ListView.builder(
      key: const ValueKey('tasks-list'),
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      itemCount: flatItems.length,
      itemBuilder: (context, index) {
        final item = flatItems[index];
        return switch (item) {
          _FlatHeaderItem(:final status) =>
            _TaskSectionLabel(status: status, colors: colors),
          _FlatTaskItem(:final task) => _TaskRow(
              task: task,
              colors: colors,
              onStatusUpdate: onStatusUpdate,
              onDelete: onDelete,
              onClaim: onClaim,
              onUnclaim: onUnclaim,
            ),
        };
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Flat list item types for ListView.builder indexed access
// ---------------------------------------------------------------------------

sealed class _FlatListItem {}

class _FlatHeaderItem extends _FlatListItem {
  _FlatHeaderItem(this.status);
  final String status;
}

class _FlatTaskItem extends _FlatListItem {
  _FlatTaskItem(this.task);
  final TaskItem task;
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
      'closed' => '已关闭',
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
    'closed' => '✕',
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
    'closed' => colors.textTertiary,
    _ => colors.textTertiary,
  };
}

/// Returns the accessible label for a task status symbol.
///
/// Used for screen reader announcements on status indicators and
/// combined task row descriptions.
String _statusAccessibilityLabel(String status) {
  return switch (status) {
    'todo' => 'To Do',
    'in_progress' => 'In Progress',
    'in_review' => 'In Review',
    'done' => 'Done',
    'closed' => 'Cancelled',
    _ => status,
  };
}

// ---------------------------------------------------------------------------
// Task row
// ---------------------------------------------------------------------------

class _TaskRow extends ConsumerStatefulWidget {
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
  ConsumerState<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<_TaskRow> {
  OverlayEntry? _overlayEntry;
  bool _dropAccepted = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _insertOverlay() {
    _dropAccepted = false;
    HapticFeedback.mediumImpact();
    final task = widget.task;
    _overlayEntry = OverlayEntry(
      builder: (_) => TaskStatusOverlay(
        key: const ValueKey('task-status-overlay'),
        currentStatus: task.status,
        onDropAccepted: () {
          // Prevents onDragEnd from removing the overlay during success
          // animation — the overlay will call onStatusAccepted after the
          // animation completes.
          _dropAccepted = true;
        },
        onStatusAccepted: (newStatus) {
          _removeOverlay();
          widget.onStatusUpdate(task, newStatus);
        },
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final colors = widget.colors;
    final isDone = task.status == 'done';
    final isClosed = task.status == 'closed';
    final isTerminal = isDone || isClosed;
    // All non-closed tasks support drag-to-change-status.
    final isDraggable = !isClosed;

    // Build combined accessibility label for screen readers.
    final statusLabel = _statusAccessibilityLabel(task.status);
    final assigneePart =
        task.claimedByName != null ? ', ${task.claimedByName}' : '';
    final combinedLabel =
        '#${task.taskNumber} ${task.title}, $statusLabel$assigneePart';

    Widget row = Semantics(
      key: ValueKey('task-row-${task.id}'),
      label: combinedLabel,
      onLongPress: !isClosed ? () => _showTaskActions(context) : null,
      child: InkWell(
        key: ValueKey('task-${task.id}'),
        onTap: () => _onPrimaryTap(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Status symbol — excluded (covered by combined row label)
              ExcludeSemantics(
                child: Semantics(
                  label: statusLabel,
                  child: Text(
                    _statusSymbol(task.status),
                    style: AppTypography.title.copyWith(
                      color: _statusColor(task.status, colors),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Task number + title — excluded (covered by combined row label)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    '#${task.taskNumber} ${task.title}',
                    style: AppTypography.body.copyWith(
                      color: colors.text,
                      decoration:
                          isTerminal ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Assignee avatar — excluded (covered by combined row label)
              if (task.claimedByName != null) ...[
                const SizedBox(width: AppSpacing.sm),
                ExcludeSemantics(
                  child: CircleAvatar(
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
                ),
              ],

              // Action sheet button — NOT excluded, remains separately
              // focusable for screen readers.
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  key: ValueKey('task-actions-${task.id}'),
                  tooltip: 'Task actions',
                  icon: Icon(
                    Icons.more_horiz,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => _showTaskActions(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Wrap in LongPressDraggable for non-closed tasks.
    if (isDraggable) {
      row = LongPressDraggable<TaskItem>(
        data: task,
        delay: const Duration(milliseconds: 400),
        onDragStarted: _insertOverlay,
        onDragEnd: (_) {
          // If a drop was accepted, the overlay handles its own dismissal
          // after the success animation completes.
          if (!_dropAccepted) {
            _removeOverlay();
          }
        },
        feedback: _buildDragGhost(),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Text(
                  _statusSymbol(task.status),
                  style: AppTypography.title.copyWith(
                    color: _statusColor(task.status, colors),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '#${task.taskNumber} ${task.title}',
                    style: AppTypography.body.copyWith(color: colors.text),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        child: row,
      );
    }

    // Wrap with left-swipe "Done" action (only for active tasks).
    if (!isTerminal) {
      row = SwipeActionWrapper(
        itemKey: task.id,
        enabled: true,
        action: SwipeActionConfig(
          label: 'Done',
          icon: Icons.check_circle_outline,
          color: colors.success,
        ),
        onAction: () => widget.onStatusUpdate(task, 'done'),
        child: row,
      );
    }

    if (isTerminal) {
      row = Opacity(
        key: ValueKey('task-row-opacity-${task.id}'),
        opacity: 0.5,
        child: row,
      );
    }

    return row;
  }

  /// Drag ghost: elevated rotated card showing task title.
  Widget _buildDragGhost() {
    final task = widget.task;
    final colors = widget.colors;
    return Transform.scale(
      scale: 1.03,
      child: Transform.rotate(
        angle: -0.026,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: colors.surfaceAlt,
          child: Container(
            width: 280,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusSymbol(task.status),
                  style: AppTypography.title.copyWith(
                    color: _statusColor(task.status, colors),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '#${task.taskNumber} ${task.title}',
                    style: AppTypography.body.copyWith(color: colors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onPrimaryTap() {
    final serverId = ref.read(currentTasksServerIdProvider).value;
    if (widget.task.channelType == 'dm') {
      context.push('/servers/$serverId/dms/${widget.task.channelId}');
    } else {
      context.push('/servers/$serverId/channels/${widget.task.channelId}');
    }
  }

  Future<void> _showTaskActions(BuildContext context) async {
    final task = widget.task;
    final actions = <ListActionItem>[
      if (task.status != 'done' && task.status != 'closed')
        const ListActionItem(
          key: 'task-action-done',
          label: 'Mark Done',
          icon: Icons.check_circle_outline,
        ),
      if (task.status != 'closed')
        const ListActionItem(
          key: 'task-action-close',
          label: '关闭任务',
          icon: Icons.close,
        ),
      if (task.status == 'todo')
        const ListActionItem(
          key: 'task-action-start',
          label: 'Start',
          icon: Icons.play_arrow,
        ),
      if (task.status == 'in_progress')
        const ListActionItem(
          key: 'task-action-review',
          label: 'Move to Review',
          icon: Icons.rate_review_outlined,
        ),
      if (task.status == 'done' || task.status == 'closed')
        const ListActionItem(
          key: 'task-action-reopen',
          label: 'Reopen',
          icon: Icons.replay,
        ),
      if (task.status == 'in_review')
        const ListActionItem(
          key: 'task-action-revert-in-progress',
          label: 'Revert to In Progress',
          icon: Icons.undo,
        ),
      if (task.status == 'in_progress')
        const ListActionItem(
          key: 'task-action-revert-todo',
          label: 'Revert to To Do',
          icon: Icons.undo,
        ),
      if (task.claimedById == null)
        const ListActionItem(
          key: 'task-action-claim',
          label: 'Claim',
          icon: Icons.person_add,
        ),
      if (task.claimedById != null)
        const ListActionItem(
          key: 'task-action-unclaim',
          label: 'Unclaim',
          icon: Icons.person_remove,
        ),
      if (!task.isLegacy)
        const ListActionItem(
          key: 'task-action-delete',
          label: 'Delete',
          icon: Icons.delete_outline,
          isDestructive: true,
        ),
    ];

    final result = await showListActionSheet(
      context: context,
      actions: actions,
      title: '#${task.taskNumber} ${task.title}',
    );

    switch (result) {
      case 'task-action-done':
        widget.onStatusUpdate(task, 'done');
      case 'task-action-close':
        widget.onStatusUpdate(task, 'closed');
      case 'task-action-start':
        widget.onStatusUpdate(task, 'in_progress');
      case 'task-action-review':
        widget.onStatusUpdate(task, 'in_review');
      case 'task-action-reopen':
        widget.onStatusUpdate(task, 'todo');
      case 'task-action-revert-in-progress':
        widget.onStatusUpdate(task, 'in_progress');
      case 'task-action-revert-todo':
        widget.onStatusUpdate(task, 'todo');
      case 'task-action-claim':
        widget.onClaim(task);
      case 'task-action-unclaim':
        widget.onUnclaim(task);
      case 'task-action-delete':
        widget.onDelete(task);
    }
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
