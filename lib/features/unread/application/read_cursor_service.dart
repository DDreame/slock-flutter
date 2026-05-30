import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';

/// Granular read cursor service — batches + deduplicates
/// `POST /channels/{id}/read` calls per channel.
///
/// Architecture (matches web bundle):
/// - Tracks `highestSeqSeen` per channel
/// - Debounces flush (2s after last update)
/// - One in-flight request per channel (dedup)
/// - Re-flushes if seq advanced during flight
/// - Fire-and-forget (errors swallowed)
/// - Flush on dispose (channel leave / app background)
class ReadCursorService {
  ReadCursorService({
    required InboxRepository inboxRepository,
    required ServerScopeId serverId,
    @visibleForTesting Duration debounceDuration = const Duration(seconds: 2),
  })  : _inboxRepository = inboxRepository,
        _serverId = serverId,
        _debounceDuration = debounceDuration;

  final InboxRepository _inboxRepository;
  final ServerScopeId _serverId;
  final Duration _debounceDuration;

  /// Highest seq seen per channel (pending flush).
  final Map<String, int> _pendingSeqs = {};

  /// Seq value currently in-flight per channel.
  final Map<String, int> _inFlightSeqs = {};

  /// Debounce timers per channel.
  final Map<String, Timer> _debounceTimers = {};

  /// Whether this service has been disposed.
  bool _disposed = false;

  /// Record that the user has seen messages up to [seq] in [channelId].
  ///
  /// Debounces the API call. Only the highest seq per channel is flushed.
  void markSeen(String channelId, int seq) {
    if (_disposed || seq <= 0) return;

    final current = _pendingSeqs[channelId] ?? 0;
    if (seq <= current) return; // Already seen a higher seq

    _pendingSeqs[channelId] = seq;
    _scheduleFlush(channelId);
  }

  /// Immediately flush all pending cursors (e.g. on channel leave / background).
  Future<void> flushAll() async {
    // Cancel all pending timers — we flush immediately.
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    final channels = _pendingSeqs.keys.toList();
    await Future.wait(channels.map(_flush));
  }

  /// Dispose the service — flushes remaining cursors and cancels timers.
  Future<void> dispose() async {
    _disposed = true;
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    // Best-effort flush of remaining pending seqs.
    final channels = _pendingSeqs.keys.toList();
    await Future.wait(channels.map(_flush));
  }

  void _scheduleFlush(String channelId) {
    _debounceTimers[channelId]?.cancel();
    _debounceTimers[channelId] = Timer(_debounceDuration, () {
      _debounceTimers.remove(channelId);
      _flush(channelId);
    });
  }

  Future<void> _flush(String channelId) async {
    final seq = _pendingSeqs[channelId];
    if (seq == null || seq <= 0) return;

    // Dedup: if already in-flight for this channel, skip.
    if (_inFlightSeqs.containsKey(channelId)) return;

    _inFlightSeqs[channelId] = seq;
    _pendingSeqs.remove(channelId);

    try {
      await _inboxRepository.markItemReadAt(
        _serverId,
        channelId: channelId,
        seq: seq,
      );
    } catch (_) {
      // Fire-and-forget — errors are swallowed (matches web behavior).
    } finally {
      _inFlightSeqs.remove(channelId);

      // If seq advanced during flight, re-flush.
      final newPending = _pendingSeqs[channelId];
      if (newPending != null && newPending > seq && !_disposed) {
        _flush(channelId);
      }
    }
  }

  /// Test-only: returns pending seq for a channel (null if none).
  @visibleForTesting
  int? pendingSeqFor(String channelId) => _pendingSeqs[channelId];

  /// Test-only: returns whether a flush is in-flight for a channel.
  @visibleForTesting
  bool isInFlight(String channelId) => _inFlightSeqs.containsKey(channelId);
}

/// Provider for [ReadCursorService] scoped to the active server.
///
/// The service persists for the server session. It is invalidated and
/// re-created when the active server changes.
/// Returns `null` when no server is selected.
final readCursorServiceProvider = Provider<ReadCursorService?>((ref) {
  final serverId = ref.watch(activeServerScopeIdProvider);
  if (serverId == null) return null;
  final inboxRepo = ref.watch(inboxRepositoryProvider);
  final service = ReadCursorService(
    inboxRepository: inboxRepo,
    serverId: serverId,
  );
  ref.onDispose(() {
    // Best-effort flush on provider teardown (server switch / logout).
    service.dispose();
  });
  return service;
});
