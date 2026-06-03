import 'package:slock_app/core/realtime/realtime_connection_state.dart';

class RealtimeWatchdogConfig {
  const RealtimeWatchdogConfig({
    this.interval = const Duration(seconds: 10),
    this.heartbeatStaleAfter = const Duration(seconds: 45),
    this.anyEventStaleAfter = const Duration(seconds: 90),
    this.reconnectingStaleAfter = const Duration(seconds: 30),
  });

  final Duration interval;
  final Duration heartbeatStaleAfter;
  final Duration anyEventStaleAfter;

  /// If the service has been in `reconnecting` state for longer than this
  /// without progress, the watchdog forces a fresh reconnect attempt.
  final Duration reconnectingStaleAfter;
}

class RealtimeWatchdogDecision {
  const RealtimeWatchdogDecision._({
    required this.shouldForceReconnect,
    this.reason,
  });

  const RealtimeWatchdogDecision.keepAlive()
      : this._(shouldForceReconnect: false);

  const RealtimeWatchdogDecision.forceReconnect(String reason)
      : this._(shouldForceReconnect: true, reason: reason);

  final bool shouldForceReconnect;
  final String? reason;
}

class RealtimeWatchdog {
  const RealtimeWatchdog({required this.config});

  final RealtimeWatchdogConfig config;

  RealtimeWatchdogDecision evaluate({
    required RealtimeConnectionState state,
    required DateTime now,
  }) {
    // INV-P0-RECONNECT: Detect stale `reconnecting` state.
    // If a reconnect attempt threw during connect() the state stays
    // `reconnecting` indefinitely — neither the watchdog (which previously
    // only acted on `connected`) nor syncConnection (only acts on
    // `disconnected`) would ever retry. Treat >30s in `reconnecting` as a
    // signal to force a fresh attempt.
    if (state.status == RealtimeConnectionStatus.reconnecting) {
      final lastAttempt = state.lastForcedReconnectAt;
      if (lastAttempt != null) {
        final staleAge = now.difference(lastAttempt);
        if (staleAge >= config.reconnectingStaleAfter) {
          return RealtimeWatchdogDecision.forceReconnect(
            'stale reconnecting state ($staleAge)',
          );
        }
      }
      return const RealtimeWatchdogDecision.keepAlive();
    }

    if (!state.isConnected) {
      return const RealtimeWatchdogDecision.keepAlive();
    }

    final lastHeartbeatAt = state.lastHeartbeatAt;
    final lastAnyEventAt = state.lastAnyEventAt;
    if (lastHeartbeatAt == null || lastAnyEventAt == null) {
      return const RealtimeWatchdogDecision.keepAlive();
    }

    final heartbeatAge = now.difference(lastHeartbeatAt);
    final anyEventAge = now.difference(lastAnyEventAt);
    if (heartbeatAge >= config.heartbeatStaleAfter &&
        anyEventAge >= config.anyEventStaleAfter) {
      return RealtimeWatchdogDecision.forceReconnect(
        'heartbeat age $heartbeatAge, any-event age $anyEventAge',
      );
    }

    return const RealtimeWatchdogDecision.keepAlive();
  }
}
