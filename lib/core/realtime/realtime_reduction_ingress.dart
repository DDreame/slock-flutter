import 'dart:async';

import 'package:slock_app/core/realtime/realtime_event_envelope.dart';

class RealtimeReductionIngress {
  final StreamController<RealtimeEventEnvelope> _acceptedEventsController =
      StreamController<RealtimeEventEnvelope>.broadcast();
  final Map<String, int> _lastAcceptedSeqByScope = <String, int>{};

  Stream<RealtimeEventEnvelope> get acceptedEvents =>
      _acceptedEventsController.stream;

  Map<String, int> get lastSeqByScope =>
      Map<String, int>.unmodifiable(_lastAcceptedSeqByScope);

  bool accept(RealtimeEventEnvelope envelope) {
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

  Future<void> dispose() async {
    await _acceptedEventsController.close();
  }
}
