import 'package:flutter/foundation.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';

@immutable
class DirectMessageScopeId {
  const DirectMessageScopeId({required this.serverId, required this.value});

  factory DirectMessageScopeId.fromRouteParams({
    required String serverId,
    required String directMessageId,
  }) {
    return DirectMessageScopeId(
      serverId: ServerScopeId.fromRouteParam(serverId),
      value: directMessageId,
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
        other is DirectMessageScopeId &&
            runtimeType == other.runtimeType &&
            serverId == other.serverId &&
            value == other.value;
  }

  @override
  int get hashCode => Object.hash(serverId, value);
}
