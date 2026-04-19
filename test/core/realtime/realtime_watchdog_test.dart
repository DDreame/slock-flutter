import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';

void main() {
  test('forces reconnect only when heartbeat and any-event ages are both stale',
      () {
    const watchdog = RealtimeWatchdog(
      config: RealtimeWatchdogConfig(
        heartbeatStaleAfter: Duration(seconds: 30),
        anyEventStaleAfter: Duration(seconds: 60),
      ),
    );
    final base = DateTime(2026, 1, 1, 0, 0, 0);
    final state = RealtimeConnectionState(
      status: RealtimeConnectionStatus.connected,
      lastHeartbeatAt: base,
      lastAnyEventAt: base,
    );

    final keepAlive = watchdog.evaluate(
      state: state,
      now: base.add(const Duration(seconds: 40)),
    );
    final reconnect = watchdog.evaluate(
      state: state,
      now: base.add(const Duration(seconds: 65)),
    );

    expect(keepAlive.shouldForceReconnect, isFalse);
    expect(reconnect.shouldForceReconnect, isTrue);
    expect(reconnect.reason, contains('heartbeat age'));
  });
}
