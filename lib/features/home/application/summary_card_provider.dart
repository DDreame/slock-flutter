import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/last_active_timestamp_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #861: Smart Summary Card — pure frontend rule-based aggregation
//
// Aggregates InboxStore, HomeListStore (tasks), and lastActiveTimestamp to
// produce a summary of "what happened while you were away."
// No AI/LLM, no new network calls. Renders within 5 seconds of app resume.
// ---------------------------------------------------------------------------

/// Minimum away duration to show the summary card.
const summaryCardMinAwayDuration = Duration(minutes: 5);

/// Maximum channels shown in expanded details.
const summaryCardMaxChannels = 5;

/// Maximum task changes shown in expanded details.
const summaryCardMaxTaskChanges = 5;

/// Cap for displayed unread count.
const summaryCardMaxUnreadDisplay = 999;

/// A channel entry in the summary card's expanded view.
@immutable
class SummaryChannelEntry {
  const SummaryChannelEntry({
    required this.channelId,
    required this.channelName,
    required this.kind,
    required this.unreadCount,
    required this.isMentioned,
  });

  final String channelId;
  final String channelName;
  final InboxItemKind kind;
  final int unreadCount;
  final bool isMentioned;
}

/// A task change entry in the summary card's expanded view.
@immutable
class SummaryTaskChange {
  const SummaryTaskChange({
    required this.taskNumber,
    required this.title,
    required this.changeType,
    required this.status,
  });

  final int taskNumber;
  final String title;

  /// 'assigned' for new assignments, 'statusChanged' for completions.
  final String changeType;
  final String status;
}

/// The full summary card state used by the widget.
@immutable
class SummaryCardState {
  const SummaryCardState({
    required this.awayDuration,
    required this.totalUnread,
    required this.mentionCount,
    required this.newTaskCount,
    required this.topChannels,
    required this.taskChanges,
    required this.remainingChannelCount,
  });

  final Duration awayDuration;
  final int totalUnread;
  final int mentionCount;
  final int newTaskCount;
  final List<SummaryChannelEntry> topChannels;
  final List<SummaryTaskChange> taskChanges;

  /// Number of additional channels beyond [topChannels].
  final int remainingChannelCount;

  /// Whether there is any content to show.
  bool get hasContent => totalUnread > 0 || newTaskCount > 0;
}

/// Session-level dismiss state — resets on next app resume.
final summaryCardDismissedProvider = StateProvider<bool>((ref) => false);

/// Computes the summary card state from reactive stores.
///
/// Returns null when:
/// - No lastActiveTimestamp (first install)
/// - Away duration < 5 minutes
/// - No unreads AND no task changes
/// - Inbox or Home not yet loaded
final summaryCardStateProvider = Provider<SummaryCardState?>((ref) {
  final lastActive = ref.watch(lastActiveTimestampProvider);
  if (lastActive == null) return null;

  final inbox = ref.watch(inboxStoreProvider);
  if (inbox.status != InboxStatus.success) return null;

  final homeState = ref.watch(homeListStoreProvider);
  if (homeState.status != HomeListStatus.success) return null;

  final awayDuration = DateTime.now().difference(lastActive);
  if (awayDuration < summaryCardMinAwayDuration) return null;

  // --- Aggregate inbox data ---
  final totalUnread = inbox.totalUnreadCount;
  final mentionCount = inbox.items.where((item) => item.isMentioned).length;

  // Rank channels: mentions first, then by unread count descending.
  final unreadItems =
      inbox.items.where((item) => item.unreadCount > 0).toList();
  unreadItems.sort((a, b) {
    if (a.isMentioned && !b.isMentioned) return -1;
    if (!a.isMentioned && b.isMentioned) return 1;
    return b.unreadCount.compareTo(a.unreadCount);
  });

  final topChannels = unreadItems
      .take(summaryCardMaxChannels)
      .map(
        (item) => SummaryChannelEntry(
          channelId: item.channelId,
          channelName: item.channelName ?? item.channelId,
          kind: item.kind,
          unreadCount: item.unreadCount,
          isMentioned: item.isMentioned,
        ),
      )
      .toList();

  final remainingChannelCount = unreadItems.length > summaryCardMaxChannels
      ? unreadItems.length - summaryCardMaxChannels
      : 0;

  // --- Aggregate task changes (assigned to me since lastActive) ---
  final taskChanges = <SummaryTaskChange>[];
  final userId = ref.watch(sessionStoreProvider.select((s) => s.userId));

  for (final task in homeState.taskItems) {
    // New assignments to current user since last active.
    if (task.claimedById == userId &&
        task.claimedAt != null &&
        task.claimedAt!.isAfter(lastActive)) {
      taskChanges.add(SummaryTaskChange(
        taskNumber: task.taskNumber,
        title: task.title,
        changeType: 'assigned',
        status: task.status,
      ));
      continue; // Don't double-count as statusChanged.
    }
    // Completed tasks since last active.
    if (task.completedAt != null && task.completedAt!.isAfter(lastActive)) {
      taskChanges.add(SummaryTaskChange(
        taskNumber: task.taskNumber,
        title: task.title,
        changeType: 'statusChanged',
        status: task.status,
      ));
    }
  }

  // Sort: assigned first, then statusChanged.
  taskChanges.sort((a, b) {
    if (a.changeType == 'assigned' && b.changeType != 'assigned') return -1;
    if (a.changeType != 'assigned' && b.changeType == 'assigned') return 1;
    return 0;
  });

  final limitedTaskChanges =
      taskChanges.take(summaryCardMaxTaskChanges).toList();

  // Don't show card if there's nothing to report.
  if (totalUnread == 0 && limitedTaskChanges.isEmpty) return null;

  return SummaryCardState(
    awayDuration: awayDuration,
    totalUnread: totalUnread,
    mentionCount: mentionCount,
    newTaskCount: limitedTaskChanges.length,
    topChannels: topChannels,
    taskChanges: limitedTaskChanges,
    remainingChannelCount: remainingChannelCount,
  );
});
