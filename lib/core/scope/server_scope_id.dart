import 'package:flutter/foundation.dart';

@immutable
class ServerScopeId {
  const ServerScopeId(this.value);

  factory ServerScopeId.fromRouteParam(String value) => ServerScopeId(value);

  final String value;

  String get routeParam => value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ServerScopeId &&
            runtimeType == other.runtimeType &&
            value == other.value;
  }

  @override
  int get hashCode => value.hashCode;
}
