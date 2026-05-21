import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// #566: Attachment Download Priority Queue
//
// Dual-queue scheduler: visible (priority) and deferred (FIFO).
// Prioritizes attachments visible in viewport, defers offscreen.
// Only visible items are actively downloaded — deferred items wait
// until promoted via onVisibilityChanged.
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

/// Internal tracking for a single enqueued download.
class _DownloadEntry {
  _DownloadEntry({
    required this.id,
    required this.download,
    this.onCancel,
  });

  final String id;
  final Future<void> Function() download;
  final void Function()? onCancel;
}

/// Priority scheduler for attachment downloads.
///
/// Enqueue downloads with [enqueue], report viewport changes with
/// [onVisibilityChanged]. The scheduler maintains two internal queues
/// (visible priority + deferred FIFO) and limits concurrency to
/// [maxConcurrent] simultaneous downloads.
///
/// Only items in the visible queue are actively downloaded. Deferred
/// items remain idle until promoted via [onVisibilityChanged].
///
/// AutoDispose: scoped to conversation detail page lifecycle. When the
/// user navigates away and all watchers are removed, internal state
/// (including the _completed set) is naturally GC'd — preventing
/// unbounded growth across conversations.
class DownloadPriorityScheduler
    extends AutoDisposeNotifier<DownloadSchedulerState> {
  /// Maximum number of concurrent downloads.
  int get maxConcurrent => 3;

  /// All registered download entries by ID.
  final Map<String, _DownloadEntry> _entries = {};

  /// Visible (priority) queue — items the user can see.
  final List<String> _visibleQueue = [];

  /// Deferred (FIFO) queue — offscreen items.
  final List<String> _deferredQueue = [];

  /// Currently in-flight download IDs.
  final Set<String> _inFlight = {};

  /// IDs that have completed — prevents re-enqueue on widget rebuild.
  final Set<String> _completed = {};

  @override
  DownloadSchedulerState build() {
    return const DownloadSchedulerState();
  }

  /// Add a download to the scheduler.
  ///
  /// The [download] callback is invoked when the scheduler decides to start
  /// the download (based on visibility and concurrency limits).
  ///
  /// [onCancel] is called by the scheduler if it decides to cancel the
  /// in-progress download (e.g. item scrolled far offscreen). Callers use
  /// this to abort network requests or free resources.
  void enqueue(
    String id,
    Future<void> Function() download, {
    void Function()? onCancel,
  }) {
    // Skip if already tracked or previously completed.
    if (_entries.containsKey(id) || _completed.contains(id)) return;

    _entries[id] = _DownloadEntry(
      id: id,
      download: download,
      onCancel: onCancel,
    );

    // Start in deferred queue (offscreen until told otherwise).
    _deferredQueue.add(id);
    _emitState();
  }

  /// Notify the scheduler that an item's viewport visibility changed.
  ///
  /// When [isVisible] is true, the item is promoted to the priority queue.
  /// When false, it may be deferred or cancelled depending on thresholds.
  void onVisibilityChanged(String id, bool isVisible) {
    if (!_entries.containsKey(id)) return;

    if (isVisible) {
      // Promote to visible queue (if not already in-flight or visible).
      _deferredQueue.remove(id);
      if (!_inFlight.contains(id) && !_visibleQueue.contains(id)) {
        _visibleQueue.add(id);
      }
    } else {
      // Cancel if in-flight, move to deferred.
      if (_inFlight.contains(id)) {
        _inFlight.remove(id);
        _entries[id]?.onCancel?.call();
        _deferredQueue.add(id);
      } else {
        _visibleQueue.remove(id);
        if (!_deferredQueue.contains(id)) {
          _deferredQueue.add(id);
        }
      }
    }

    _emitState();
    _pump();
  }

  /// Internal pump: start downloads up to [maxConcurrent].
  ///
  /// Only pulls from the visible queue. Deferred items remain idle
  /// until promoted via [onVisibilityChanged].
  void _pump() {
    while (_inFlight.length < maxConcurrent && _visibleQueue.isNotEmpty) {
      final id = _visibleQueue.removeAt(0);
      _startDownload(id);
    }
    _emitState();
  }

  /// Start a single download and track its completion.
  void _startDownload(String id) {
    final entry = _entries[id];
    if (entry == null) return;

    _inFlight.add(id);

    // Fire the download and handle completion.
    entry.download().then((_) {
      _onDownloadComplete(id);
    }).catchError((_) {
      _onDownloadComplete(id);
    });
  }

  /// Called when a download finishes (success or error).
  void _onDownloadComplete(String id) {
    if (!_inFlight.remove(id)) return; // Already cancelled/removed.
    _entries.remove(id);
    _completed.add(id);
    _emitState();
    _pump();
  }

  /// Emit current state to watchers.
  void _emitState() {
    state = DownloadSchedulerState(
      inFlight: Set<String>.from(_inFlight),
      pending: List<String>.from(_visibleQueue),
      deferred: Set<String>.from(_deferredQueue),
    );
  }
}

final downloadSchedulerProvider = AutoDisposeNotifierProvider<
    DownloadPriorityScheduler, DownloadSchedulerState>(
  DownloadPriorityScheduler.new,
);
