import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

// ---------------------------------------------------------------------------
// #579: Home Task Section Memoization
//
// Derives a filtered + sorted + sliced list of active tasks with resolved
// channel names from `homeListStoreProvider`. By selecting only the fields
// it needs (`taskItems`, `pinnedChannels`, `channels`), this provider
// avoids recomputing when unrelated state (DMs, agents, timestamps) changes.
// ---------------------------------------------------------------------------

/// Maximum number of tasks surfaced in the Home card.
const homeTaskSectionMaxItems = 5;

/// Lightweight view-model for a single task row in the Home card.
@immutable
class HomeTaskItem {
  const HomeTaskItem({
    required this.taskId,
    required this.title,
    required this.status,
    required this.channelName,
    required this.claimedByName,
    required this.claimedAt,
  });

  final String taskId;
  final String title;
  final String status;
  final String channelName;
  final String? claimedByName;
  final DateTime? claimedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HomeTaskItem &&
            runtimeType == other.runtimeType &&
            taskId == other.taskId &&
            title == other.title &&
            status == other.status &&
            channelName == other.channelName &&
            claimedByName == other.claimedByName &&
            claimedAt == other.claimedAt;
  }

  @override
  int get hashCode => Object.hash(
        taskId,
        title,
        status,
        channelName,
        claimedByName,
        claimedAt,
      );
}

/// Input record for memoization — only the fields needed for task section.
@immutable
class _TaskSectionInput {
  const _TaskSectionInput({
    required this.taskItems,
    required this.pinnedChannels,
    required this.channels,
  });

  final List<TaskItem> taskItems;
  final List<HomeChannelSummary> pinnedChannels;
  final List<HomeChannelSummary> channels;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _TaskSectionInput &&
            runtimeType == other.runtimeType &&
            listEquals(taskItems, other.taskItems) &&
            listEquals(pinnedChannels, other.pinnedChannels) &&
            listEquals(channels, other.channels);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(taskItems),
        Object.hashAll(pinnedChannels),
        Object.hashAll(channels),
      );
}

/// Provides a memoized, filtered + sorted list of active tasks for the
/// Home card. Only recomputes when `taskItems` or channels change.
final homeTaskSectionProvider = Provider<List<HomeTaskItem>>((ref) {
  final input = ref.watch(
    homeListStoreProvider.select(
      (state) => _TaskSectionInput(
        taskItems: state.taskItems,
        pinnedChannels: state.pinnedChannels,
        channels: state.channels,
      ),
    ),
  );

  return _computeTaskSection(
    input.taskItems,
    input.pinnedChannels,
    input.channels,
  );
});

/// Pure computation: filter, sort, slice, and resolve channel names.
List<HomeTaskItem> _computeTaskSection(
  List<TaskItem> taskItems,
  List<HomeChannelSummary> pinnedChannels,
  List<HomeChannelSummary> channels,
) {
  // Build channel name map from both pinned and unpinned channels.
  final channelNameMap = <String, String>{
    for (final ch in pinnedChannels) ch.scopeId.value: ch.name,
    for (final ch in channels) ch.scopeId.value: ch.name,
  };

  // Filter: only in_progress + todo
  final activeTasks = taskItems
      .where(
        (task) => task.status == 'in_progress' || task.status == 'todo',
      )
      .toList();

  // Sort: in_progress first, then todo
  activeTasks.sort((a, b) {
    final aRank = a.status == 'in_progress' ? 0 : 1;
    final bRank = b.status == 'in_progress' ? 0 : 1;
    return aRank.compareTo(bRank);
  });

  // Slice: max items
  final visible = activeTasks.length > homeTaskSectionMaxItems
      ? activeTasks.sublist(0, homeTaskSectionMaxItems)
      : activeTasks;

  // Map to view-model with resolved channel names.
  return visible
      .map(
        (task) => HomeTaskItem(
          taskId: task.id,
          title: task.title,
          status: task.status,
          channelName: channelNameMap[task.channelId] ?? task.channelId,
          claimedByName: task.claimedByName,
          claimedAt: task.claimedAt,
        ),
      )
      .toList();
}
