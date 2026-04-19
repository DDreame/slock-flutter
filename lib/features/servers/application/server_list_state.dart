import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';

enum ServerListStatus { initial, loading, success, failure }

@immutable
class ServerListState {
  const ServerListState({
    this.status = ServerListStatus.initial,
    this.servers = const [],
    this.failure,
  });

  final ServerListStatus status;
  final List<ServerSummary> servers;
  final AppFailure? failure;

  ServerListState copyWith({
    ServerListStatus? status,
    List<ServerSummary>? servers,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return ServerListState(
      status: status ?? this.status,
      servers: servers ?? this.servers,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ServerListState &&
            runtimeType == other.runtimeType &&
            status == other.status &&
            listEquals(servers, other.servers) &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(servers),
        failure,
      );
}
