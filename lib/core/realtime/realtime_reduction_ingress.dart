import 'dart:async';
import 'dart:math' show max;

import 'package:slock_app/core/realtime/realtime_event_envelope.dart';

class RealtimeReductionIngress {
  final StreamController<RealtimeEventEnvelope> _acceptedEventsController =
      StreamController<RealtimeEventEnvelope>.broadcast();
  final Map<String, int> _lastAcceptedSeqByScope = <String, int>{};
  bool _disposed = false;

  Stream<RealtimeEventEnvelope> get acceptedEvents =>
      _acceptedEventsController.stream;

  Map<String, int> get lastSeqByScope =>
      Map<String, int>.unmodifiable(_lastAcceptedSeqByScope);

  bool accept(RealtimeEventEnvelope envelope) {
    if (_disposed) return false;

    final seq = envelope.seq;
    var emitEnvelope = envelope;
    if (seq != null) {
      final lastSeq = _lastAcceptedSeqByScope[envelope.scopeKey];
      if (lastSeq != null && seq <= lastSeq) {
        return false;
      }
      if (lastSeq != null && seq > lastSeq + 1) {
        emitEnvelope = envelope.withGapDetected();
      }
      _lastAcceptedSeqByScope[envelope.scopeKey] = seq;
    }

    _acceptedEventsController.add(emitEnvelope);
    return true;
  }

  /// Accept a batch of events from sync:resume:response.
  ///
  /// Bypasses seq-ordering rejection (these fill gaps) but still updates
  /// [_lastAcceptedSeqByScope]. Distinct from [accept] because:
  /// - Normal [accept] rejects events with seq <= lastSeq (dedup).
  /// - [acceptSyncBatch] always accepts (gap-fill messages may have seqs
  ///   between existing ones).
  /// - Still updates lastSeqByScope to the max so future duplicates are
  ///   rejected.
  void acceptSyncBatch(List<RealtimeEventEnvelope> events) {
    if (_disposed) return;
    for (final event in events) {
      if (event.seq != null && event.scopeKey.isNotEmpty) {
        final currentMax = _lastAcceptedSeqByScope[event.scopeKey] ?? 0;
        _lastAcceptedSeqByScope[event.scopeKey] = max(currentMax, event.seq!);
      }
      // Mark as batch event so downstream consumers can coalesce refreshes.
      final batchEvent = RealtimeEventEnvelope(
        eventType: event.eventType,
        scopeKey: event.scopeKey,
        seq: event.seq,
        payload: event.payload,
        receivedAt: event.receivedAt,
        gapDetected: event.gapDetected,
        isSyncBatchEvent: true,
      );
      _acceptedEventsController.add(batchEvent);
    }
  }

  /// Clears all tracked sequence numbers.
  ///
  /// Called on server switch so that events from the new server are not
  /// rejected based on stale seq values from the previous connection.
  void reset() {
    _lastAcceptedSeqByScope.clear();
  }

  /// INV-856: Advances the seq cursor for [scopeKey] without emitting events.
  ///
  /// Used when a sync:resume:response returns `messages: []` with a
  /// `currentSeq` — the cursor must still advance to prevent livelock on
  /// the next re-emit of sync:resume.
  void advanceSeq(String scopeKey, int seq) {
    if (_disposed) return;
    final currentMax = _lastAcceptedSeqByScope[scopeKey] ?? 0;
    _lastAcceptedSeqByScope[scopeKey] = max(currentMax, seq);
  }

  Future<void> dispose() async {
    _disposed = true;
    _lastAcceptedSeqByScope.clear();
    await _acceptedEventsController.close();
  }
}
