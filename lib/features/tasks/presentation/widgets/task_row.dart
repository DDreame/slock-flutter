import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/list_action_sheet.dart';
import 'package:slock_app/app/widgets/swipe_action_wrapper.dart';
import 'package:slock_app/core/haptic/haptic_service.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page_helpers.dart';
import 'package:slock_app/features/tasks/presentation/widgets/task_status_overlay.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// Task row widget extracted from tasks_page.dart.
// ---------------------------------------------------------------------------

class TaskRow extends ConsumerStatefulWidget {
  const TaskRow({
    super.key,
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
  ConsumerState<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<TaskRow> {
  OverlayEntry? _overlayEntry;
  bool _dropAccepted = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _insertOverlay() {
    _dropAccepted = false;
    ref.read(hapticServiceProvider).mediumImpact();
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
    final statusLabel = taskStatusAccessibilityLabel(task.status, context);
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
                    taskStatusSymbol(task.status),
                    style: AppTypography.title.copyWith(
                      color: taskStatusColor(task.status, colors),
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
                  tooltip: context.l10n.tasksActionsTooltip,
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
                  taskStatusSymbol(task.status),
                  style: AppTypography.title.copyWith(
                    color: taskStatusColor(task.status, colors),
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
          label: context.l10n.tasksSwipeDone,
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
                  taskStatusSymbol(task.status),
                  style: AppTypography.title.copyWith(
                    color: taskStatusColor(task.status, colors),
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
    final l10n = context.l10n;
    final actions = <ListActionItem>[
      if (task.status != 'done' && task.status != 'closed')
        ListActionItem(
          key: 'task-action-done',
          label: l10n.tasksActionMarkDone,
          icon: Icons.check_circle_outline,
        ),
      if (task.status != 'closed')
        ListActionItem(
          key: 'task-action-close',
          label: l10n.tasksActionClose,
          icon: Icons.close,
        ),
      if (task.status == 'todo')
        ListActionItem(
          key: 'task-action-start',
          label: l10n.tasksActionStart,
          icon: Icons.play_arrow,
        ),
      if (task.status == 'in_progress')
        ListActionItem(
          key: 'task-action-review',
          label: l10n.tasksActionMoveToReview,
          icon: Icons.rate_review_outlined,
        ),
      if (task.status == 'done' || task.status == 'closed')
        ListActionItem(
          key: 'task-action-reopen',
          label: l10n.tasksActionReopen,
          icon: Icons.replay,
        ),
      if (task.status == 'in_review')
        ListActionItem(
          key: 'task-action-revert-in-progress',
          label: l10n.tasksActionRevertInProgress,
          icon: Icons.undo,
        ),
      if (task.status == 'in_progress')
        ListActionItem(
          key: 'task-action-revert-todo',
          label: l10n.tasksActionRevertTodo,
          icon: Icons.undo,
        ),
      if (task.claimedById == null)
        ListActionItem(
          key: 'task-action-claim',
          label: l10n.tasksActionClaim,
          icon: Icons.person_add,
        ),
      if (task.claimedById != null)
        ListActionItem(
          key: 'task-action-unclaim',
          label: l10n.tasksActionUnclaim,
          icon: Icons.person_remove,
        ),
      if (!task.isLegacy)
        ListActionItem(
          key: 'task-action-delete',
          label: l10n.tasksActionDelete,
          icon: Icons.delete_outline,
          isDestructive: true,
        ),
    ];

    final result = await showListActionSheet(
      context: context,
      actions: actions,
      title: '#${task.taskNumber} ${task.title}',
      onOpenHaptic: () => ref.read(hapticServiceProvider).mediumImpact(),
    );

    if (!mounted) return;

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
