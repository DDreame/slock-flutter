import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// #566: Attachment Download Priority Queue
//
// Dual-queue scheduler: visible (priority) and deferred (FIFO).
// Prioritizes attachments visible in viewport, defers offscreen.
// Phase B implements the full scheduling logic.
// ---------------------------------------------------------------------------

/// Observable state of the download scheduler.
class DownloadSchedulerState {
  const DownloadSchedulerState({
    this.inFlight = const {},
    this.pending = const [],
    this.deferred = const {},
  });

  /// IDs of downloads currently in progress.
  final Set<String> inFlight;

  /// Ordered list of visible-but-waiting download IDs.
  final List<String> pending;

  /// IDs of offscreen downloads waiting for visibility.
  final Set<String> deferred;
}

/// Priority scheduler for attachment downloads.
///
/// Enqueue downloads with [enqueue], report viewport changes with
/// [onVisibilityChanged]. The scheduler maintains two internal queues
/// (visible priority + deferred FIFO) and limits concurrency to
/// [maxConcurrent] simultaneous downloads.
///
/// Stub — Phase B implements the full scheduling logic.
class DownloadPriorityScheduler extends Notifier<DownloadSchedulerState> {
  /// Maximum number of concurrent downloads.
  int get maxConcurrent => 3;

  @override
  DownloadSchedulerState build() => const DownloadSchedulerState();

  /// Add a download to the scheduler.
  ///
  /// The [download] callback is invoked when the scheduler decides to start
  /// the download (based on visibility and concurrency limits).
  void enqueue(String id, Future<void> Function() download) {
    // Phase B implementation.
  }

  /// Notify the scheduler that an item's viewport visibility changed.
  ///
  /// When [isVisible] is true, the item is promoted to the priority queue.
  /// When false, it may be deferred or cancelled depending on thresholds.
  void onVisibilityChanged(String id, bool isVisible) {
    // Phase B implementation.
  }
}

final downloadSchedulerProvider =
    NotifierProvider<DownloadPriorityScheduler, DownloadSchedulerState>(
  DownloadPriorityScheduler.new,
);
