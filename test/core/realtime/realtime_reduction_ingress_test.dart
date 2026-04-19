import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';

void main() {
  test('rejects stale events for the same scope based on seq', () async {
    final ingress = RealtimeReductionIngress();
    addTearDown(ingress.dispose);

    final acceptedEvents = <RealtimeEventEnvelope>[];
    final subscription = ingress.acceptedEvents.listen(acceptedEvents.add);
    addTearDown(subscription.cancel);

    final now = DateTime(2026);
    final accepted = ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'message.created',
        scopeKey: 'server:1/channel:2',
        seq: 10,
        payload: const {'id': 'm1'},
        receivedAt: now,
      ),
    );
    final rejected = ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'message.updated',
        scopeKey: 'server:1/channel:2',
        seq: 9,
        payload: const {'id': 'm1'},
        receivedAt: now,
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(accepted, isTrue);
    expect(rejected, isFalse);
    expect(acceptedEvents, hasLength(1));
    expect(ingress.lastSeqByScope['server:1/channel:2'], 10);
  });

  test('accepts events without sequence numbers', () async {
    final ingress = RealtimeReductionIngress();
    addTearDown(ingress.dispose);

    final acceptedEvents = <RealtimeEventEnvelope>[];
    final subscription = ingress.acceptedEvents.listen(acceptedEvents.add);
    addTearDown(subscription.cancel);

    final accepted = ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'presence.changed',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        payload: const {'agentId': 'a1'},
        receivedAt: DateTime(2026),
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(accepted, isTrue);
    expect(acceptedEvents, hasLength(1));
  });
}
