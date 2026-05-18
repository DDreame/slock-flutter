import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';

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

/// Provides a memoized, filtered + sorted list of active tasks for the
/// Home card. Only recomputes when `taskItems` or channels change.
final homeTaskSectionProvider = Provider<List<HomeTaskItem>>((ref) {
  // Phase B will select from homeListStoreProvider.
  ref.watch(homeListStoreProvider);
  throw UnimplementedError('homeTaskSectionProvider: Phase B');
});
