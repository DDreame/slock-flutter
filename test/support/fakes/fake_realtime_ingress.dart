import 'package:slock_app/core/realtime/realtime_event_envelope.dart';
import 'package:slock_app/core/realtime/realtime_reduction_ingress.dart';

/// Shared fake [RealtimeReductionIngress] for tests.
///
/// Extends the real ingress to add call tracking and optional failure
/// injection.  Tests can inspect [acceptedEnvelopes] and [rejectedEnvelopes]
/// to verify event flow without wiring custom stream listeners.
class FakeRealtimeIngress extends RealtimeReductionIngress {
  FakeRealtimeIngress({this.shouldRejectAll = false});

  /// When `true`, [accept] always returns `false` and drops every event.
  bool shouldRejectAll;

  /// All envelopes that were accepted (deduplication passed).
  final List<RealtimeEventEnvelope> acceptedEnvelopes = [];

  /// All envelopes that were rejected (duplicate seq or [shouldRejectAll]).
  final List<RealtimeEventEnvelope> rejectedEnvelopes = [];

  @override
  bool accept(RealtimeEventEnvelope envelope) {
    if (shouldRejectAll) {
      rejectedEnvelopes.add(envelope);
      return false;
    }
    final accepted = super.accept(envelope);
    if (accepted) {
      acceptedEnvelopes.add(envelope);
    } else {
      rejectedEnvelopes.add(envelope);
    }
    return accepted;
  }

  /// Resets all tracked state without disposing the underlying stream.
  void reset() {
    acceptedEnvelopes.clear();
    rejectedEnvelopes.clear();
  }
}
