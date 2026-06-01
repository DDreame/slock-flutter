import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_status_tokens.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/deep_link_resource_error_view.dart';
import 'package:slock_app/app/widgets/list_action_sheet.dart';
import 'package:slock_app/app/widgets/snackbar_utils.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
import 'package:slock_app/app/widgets/swipe_action_wrapper.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/presentation/widgets/task_status_overlay.dart';
import 'package:slock_app/l10n/l10n.dart';

// -- Filter chip Z2 spec tokens --
const double _kFilterChipHeight = 32.0;
const double _kFilterChipRadius = 16.0;
const double _kFilterChipHorizontalPadding = 14.0;
const double _kFilterChipFontSize = 13.0;
const FontWeight _kFilterChipFontWeight = FontWeight.w500;
const double _kFilterChipGap = 8.0;

/// Hoisted border radius for _FilterChip. Exposed for hoist identity tests.
@visibleForTesting
final filterChipBorderRadius = BorderRadius.circular(_kFilterChipRadius);

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

    // INV-SELECT-TASKS-1: Only rebuild on layout-decision fields.
    // Individual task item mutations within the list don't require page-level
    // scaffold rebuild — only status transitions and empty/non-empty threshold.
    // Items are watched independently by _TasksListSurface (ConsumerStatefulWidget)
    // via tasksStoreProvider.select((s) => s.items).
    // INV-SELECT-TASKS-2: Include failure for the failure view (#800 P2-5).
    final (:status, :isEmpty, :isRefreshing, :failure) = ref.watch(
      tasksStoreProvider.select(
        (s) => (
          status: s.status,
          isEmpty: s.items.isEmpty,
          isRefreshing: s.isRefreshing,
          failure: s.failure,
        ),
      ),
    );
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
      body: switch (status) {
        TasksStatus.initial || TasksStatus.loading when isEmpty => ListView(
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
            colors: colors,
            isRefreshing: true,
            onStatusUpdate: _updateStatus,
            onDelete: _deleteTask,
            onClaim: _claimTask,
            onUnclaim: _unclaimTask,
            onNew: _showCreateTaskDialog,
            channels: channels,
          ),
        TasksStatus.initial ||
        TasksStatus.failure when DeepLinkResourceErrorView.handles(failure) =>
          DeepLinkResourceErrorView(failure: failure!),
        TasksStatus.initial || TasksStatus.failure => _TasksFailureView(
            message: failure?.userMessage(context.l10n) ??
                context.l10n.tasksLoadFailed,
            onRetry: ref.read(tasksStoreProvider.notifier).retry,
          ),
        TasksStatus.success when isEmpty => SafeArea(
            child: Column(
              children: [
                _TasksHeader(colors: colors, onNew: _showCreateTaskDialog),
                Expanded(
                  child: Center(child: Text(context.l10n.tasksEmptyAll)),
                ),
              ],
            ),
          ),
        TasksStatus.success => _TasksListSurface(
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
      showAppSnackBar(context, context.l10n.tasksNoChannelsAvailable);
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
              showAppSnackBar(context, context.l10n.tasksCreatedSnackbar);
            } on AppFailure catch (failure) {
              if (!mounted) return;
              showAppSnackBar(context, failure.userMessage(context.l10n));
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
      showAppSnackBarWithAction(
        context,
        failure.userMessage(context.l10n),
        actionLabel: context.l10n.tasksRetryAction,
        onAction: () => _updateStatus(task, newStatus),
      );
    }
  }

  Future<void> _deleteTask(TaskItem task) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            final colorScheme = Theme.of(dialogContext).colorScheme;
            return AlertDialog(
              title: Text(l10n.tasksDeleteTitle),
              content: Text(
                l10n.tasksDeleteMessage(task.title),
              ),
              actions: [
                TextButton(
                  key: const ValueKey('task-delete-cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.tasksDeleteCancel),
                ),
                FilledButton(
                  key: const ValueKey('task-delete-confirm'),
                  style: appDestructiveFilledButtonStyle(colorScheme),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.tasksDeleteConfirm),
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
      showAppSnackBar(context, l10n.tasksDeletedSnackbar);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(context, failure.userMessage(l10n));
    }
  }

  Future<void> _claimTask(TaskItem task) async {
    try {
      await ref.read(tasksStoreProvider.notifier).claimTask(task.id);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(context, failure.userMessage(context.l10n));
    }
  }

  Future<void> _unclaimTask(TaskItem task) async {
    try {
      await ref.read(tasksStoreProvider.notifier).unclaimTask(task.id);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(context, failure.userMessage(context.l10n));
    }
  }

  void _showRefreshFailedSnackBar() {
    final l10n = context.l10n;
    showAppSnackBarWithAction(
      context,
      l10n.refreshFailedSnackbar,
      actionLabel: l10n.refreshFailedRetry,
      onAction: () => ref.read(tasksStoreProvider.notifier).load(),
    );
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
            context.l10n.tasksHeaderTitle,
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
            child: Text(context.l10n.tasksNewButton),
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
    // #653: Single-pass frequency map instead of 5× .where().length.
    final counts = <String, int>{};
    for (final t in items) {
      counts[t.status] = (counts[t.status] ?? 0) + 1;
    }
    final todoCount = counts['todo'] ?? 0;
    final progressCount = counts['in_progress'] ?? 0;
    final reviewCount = counts['in_review'] ?? 0;
    final doneCount = counts['done'] ?? 0;
    final closedCount = counts['closed'] ?? 0;

    final l10n = context.l10n;

    return Padding(
      key: const ValueKey('tasks-summary-header'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SummaryChip(
              count: todoCount,
              label: l10n.tasksSummaryTodo,
              color: colors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.lg),
            _SummaryChip(
              count: progressCount,
              label: l10n.tasksSummaryInProgress,
              color: colors.primary,
            ),
            const SizedBox(width: AppSpacing.lg),
            _SummaryChip(
              count: reviewCount,
              label: l10n.tasksSummaryReview,
              color: colors.warning,
            ),
            const SizedBox(width: AppSpacing.lg),
            _SummaryChip(
              count: doneCount,
              label: l10n.tasksSummaryDone,
              color: colors.success,
            ),
            const SizedBox(width: AppSpacing.lg),
            _SummaryChip(
              count: closedCount,
              label: l10n.tasksSummaryClosed,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.count,
    required this.label,
    required this.color,
  });

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

class _TasksListSurface extends ConsumerStatefulWidget {
  const _TasksListSurface({
    required this.colors,
    required this.onStatusUpdate,
    required this.onDelete,
    required this.onClaim,
    required this.onUnclaim,
    required this.onNew,
    this.isRefreshing = false,
    this.channels = const [],
  });

  final AppColors colors;
  final Future<void> Function(TaskItem, String) onStatusUpdate;
  final Future<void> Function(TaskItem) onDelete;
  final Future<void> Function(TaskItem) onClaim;
  final Future<void> Function(TaskItem) onUnclaim;
  final VoidCallback onNew;
  final bool isRefreshing;
  final List<HomeChannelSummary> channels;

  @override
  ConsumerState<_TasksListSurface> createState() => _TasksListSurfaceState();
}

class _TasksListSurfaceState extends ConsumerState<_TasksListSurface> {
  String? _selectedChannelId; // null = All

  // INV-SEL-816: Cache filter results — only recompute when items identity,
  // selectedChannelId, or widget.channels changes.
  List<TaskItem>? _lastItems;
  String? _lastSelectedChannelId;
  List<HomeChannelSummary>? _lastChannels;
  List<TaskItem> _cachedFilteredItems = const [];
  List<String> _cachedFilterChannelIds = const [];

  /// Build the ordered list of channel IDs for filter chips.
  ///
  /// Includes all channels from the home list (the server's channel set)
  /// that either have tasks or are available for filtering.
  List<String> _filterChannelIds(List<TaskItem> items) {
    // Start with channels that have tasks (preserving discovery order)
    final seen = <String>{};
    final ids = <String>[];
    for (final item in items) {
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

  List<TaskItem> _filteredItems(List<TaskItem> items) {
    if (_selectedChannelId == null) return items;
    return items.where((t) => t.channelId == _selectedChannelId).toList();
  }

  /// Recompute cached filter outputs only when inputs change.
  void _ensureFiltersComputed(List<TaskItem> items) {
    if (identical(items, _lastItems) &&
        _selectedChannelId == _lastSelectedChannelId &&
        identical(widget.channels, _lastChannels)) {
      return;
    }
    _lastItems = items;
    _lastSelectedChannelId = _selectedChannelId;
    _lastChannels = widget.channels;
    _cachedFilteredItems = _filteredItems(items);
    _cachedFilterChannelIds = _filterChannelIds(items);
  }

  @override
  Widget build(BuildContext context) {
    // INV-TASKS-662-SELECT-2: List surface watches items independently so
    // the scaffold above doesn't rebuild on item mutations within a non-empty
    // list.
    final items = ref.watch(
      tasksStoreProvider.select((s) => s.items),
    );
    // INV-SEL-816: Cached filter — skips recomputation when items identity
    // and selectedChannelId are unchanged (e.g. parent rebuild from
    // isRefreshing or channels prop change).
    _ensureFiltersComputed(items);
    final filteredItems = _cachedFilteredItems;
    final filterChannelIds = _cachedFilterChannelIds;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TasksHeader(colors: widget.colors, onNew: widget.onNew),
          _TasksSummaryHeader(items: filteredItems, colors: widget.colors),
          const SizedBox(height: AppSpacing.md),
          if (filterChannelIds.length > 1)
            _TasksChannelFilterBar(
              channelIds: filterChannelIds,
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
            Expanded(
              child: Center(
                child: Text(context.l10n.tasksEmptyChannel),
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
              label: context.l10n.tasksFilterAll,
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

  static final _borderRadius = filterChipBorderRadius;

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
            borderRadius: _borderRadius,
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
        _statusLabel(status, context),
        style: AppTypography.label.copyWith(
          color: colors.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static String _statusLabel(String status, BuildContext context) {
    final l10n = context.l10n;
    return switch (status) {
      'todo' => l10n.tasksSectionTodo,
      'in_progress' => l10n.tasksSectionInProgress,
      'in_review' => l10n.tasksSectionInReview,
      'done' => l10n.tasksSectionDone,
      'closed' => l10n.tasksSectionClosed,
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
String _statusAccessibilityLabel(String status, BuildContext context) {
  final l10n = context.l10n;
  return switch (status) {
    'todo' => l10n.tasksAccessibilityTodo,
    'in_progress' => l10n.tasksAccessibilityInProgress,
    'in_review' => l10n.tasksAccessibilityInReview,
    'done' => l10n.tasksAccessibilityDone,
    'closed' => l10n.tasksAccessibilityClosed,
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
    final statusLabel = _statusAccessibilityLabel(task.status, context);
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
              child: Text(context.l10n.tasksRetryButton),
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
    final l10n = context.l10n;
    return AlertDialog(
      key: const ValueKey('create-task-dialog'),
      title: Text(l10n.tasksCreateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('task-channel-dropdown'),
            initialValue: _selectedChannelId,
            decoration:
                InputDecoration(labelText: l10n.tasksCreateChannelLabel),
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
            decoration: InputDecoration(labelText: l10n.tasksCreateTitleLabel),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.tasksCreateCancel),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.tasksCreateConfirm),
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
