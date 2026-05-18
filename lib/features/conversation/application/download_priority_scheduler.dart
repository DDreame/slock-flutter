import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// #566: Attachment Download Priority Queue
//
// Dual-queue scheduler: visible (priority) and deferred (FIFO).
// Prioritizes attachments visible in viewport, defers offscreen.
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
class DownloadPriorityScheduler extends Notifier<DownloadSchedulerState> {
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

  @override
  DownloadSchedulerState build() => const DownloadSchedulerState();

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
    if (_entries.containsKey(id)) return; // already tracked

    _entries[id] = _DownloadEntry(
      id: id,
      download: download,
      onCancel: onCancel,
    );

    // Start in deferred queue (offscreen until told otherwise).
    _deferredQueue.add(id);
    _emitState();
    _pump();
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
  /// Pulls from visible queue first (priority), then fills remaining
  /// slots from deferred queue.
  void _pump() {
    // Fill from visible queue first.
    while (_inFlight.length < maxConcurrent && _visibleQueue.isNotEmpty) {
      final id = _visibleQueue.removeAt(0);
      _startDownload(id);
    }

    // Then fill from deferred if slots remain.
    while (_inFlight.length < maxConcurrent && _deferredQueue.isNotEmpty) {
      final id = _deferredQueue.removeAt(0);
      _startDownload(id);
    }

    _emitState();
  }

  /// Start a single download and track its completion.
  void _startDownload(String id) {
    final entry = _entries[id];
    if (entry == null) return;

    _inFlight.add(id);
    _emitState();

    // Fire the download and handle completion.
    entry.download().then((_) {
      _onDownloadComplete(id);
    }).catchError((_) {
      _onDownloadComplete(id);
    });
  }

  /// Called when a download finishes (success or error).
  void _onDownloadComplete(String id) {
    _inFlight.remove(id);
    _entries.remove(id);
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

final downloadSchedulerProvider =
    NotifierProvider<DownloadPriorityScheduler, DownloadSchedulerState>(
  DownloadPriorityScheduler.new,
);
