import 'dart:async';

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

  /// Clears all tracked sequence numbers.
  ///
  /// Called on server switch so that events from the new server are not
  /// rejected based on stale seq values from the previous connection.
  void reset() {
    _lastAcceptedSeqByScope.clear();
  }

  Future<void> dispose() async {
    _disposed = true;
    _lastAcceptedSeqByScope.clear();
    await _acceptedEventsController.close();
  }
}
