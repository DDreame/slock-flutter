import 'package:flutter/foundation.dart';

enum RealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

@immutable
class RealtimeConnectionState {
  const RealtimeConnectionState({
    this.status = RealtimeConnectionStatus.disconnected,
    this.lastHeartbeatAt,
    this.lastAnyEventAt,
    this.lastConnectedAt,
    this.lastDisconnectedAt,
    this.lastForcedReconnectAt,
    this.reconnectAttempts = 0,
    this.disconnectReason,
  });

  final RealtimeConnectionStatus status;
  final DateTime? lastHeartbeatAt;
  final DateTime? lastAnyEventAt;
  final DateTime? lastConnectedAt;
  final DateTime? lastDisconnectedAt;
  final DateTime? lastForcedReconnectAt;
  final int reconnectAttempts;
  final String? disconnectReason;

  bool get isConnected => status == RealtimeConnectionStatus.connected;

  RealtimeConnectionState copyWith({
    RealtimeConnectionStatus? status,
    DateTime? lastHeartbeatAt,
    DateTime? lastAnyEventAt,
    DateTime? lastConnectedAt,
    DateTime? lastDisconnectedAt,
    DateTime? lastForcedReconnectAt,
    int? reconnectAttempts,
    String? disconnectReason,
    bool clearDisconnectReason = false,
  }) {
    return RealtimeConnectionState(
      status: status ?? this.status,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      lastAnyEventAt: lastAnyEventAt ?? this.lastAnyEventAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastDisconnectedAt: lastDisconnectedAt ?? this.lastDisconnectedAt,
      lastForcedReconnectAt:
          lastForcedReconnectAt ?? this.lastForcedReconnectAt,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      disconnectReason: clearDisconnectReason
          ? null
          : (disconnectReason ?? this.disconnectReason),
    );
  }
}
