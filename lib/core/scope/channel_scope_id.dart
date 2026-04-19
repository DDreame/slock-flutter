import 'package:flutter/foundation.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';

@immutable
class ChannelScopeId {
  const ChannelScopeId({required this.serverId, required this.value});

  factory ChannelScopeId.fromRouteParams({
    required String serverId,
    required String channelId,
  }) {
    return ChannelScopeId(
      serverId: ServerScopeId.fromRouteParam(serverId),
      value: channelId,
    );
  }

  final ServerScopeId serverId;
  final String value;

  String get routeParam => value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChannelScopeId &&
            runtimeType == other.runtimeType &&
            serverId == other.serverId &&
            value == other.value;
  }

  @override
  int get hashCode => Object.hash(serverId, value);
}
