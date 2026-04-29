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
    this.isCreating = false,
    this.isJoiningInvite = false,
    this.savingServerIds = const <String>{},
    this.deletingServerIds = const <String>{},
    this.leavingServerIds = const <String>{},
  });

  final ServerListStatus status;
  final List<ServerSummary> servers;
  final AppFailure? failure;
  final bool isCreating;
  final bool isJoiningInvite;
  final Set<String> savingServerIds;
  final Set<String> deletingServerIds;
  final Set<String> leavingServerIds;

  bool isSaving(String serverId) => savingServerIds.contains(serverId);
  bool isDeleting(String serverId) => deletingServerIds.contains(serverId);
  bool isLeaving(String serverId) => leavingServerIds.contains(serverId);
  bool isBusy(String serverId) =>
      isSaving(serverId) || isDeleting(serverId) || isLeaving(serverId);

  ServerListState copyWith({
    ServerListStatus? status,
    List<ServerSummary>? servers,
    AppFailure? failure,
    bool clearFailure = false,
    bool? isCreating,
    bool? isJoiningInvite,
    Set<String>? savingServerIds,
    Set<String>? deletingServerIds,
    Set<String>? leavingServerIds,
  }) {
    return ServerListState(
      status: status ?? this.status,
      servers: servers ?? this.servers,
      failure: clearFailure ? null : (failure ?? this.failure),
      isCreating: isCreating ?? this.isCreating,
      isJoiningInvite: isJoiningInvite ?? this.isJoiningInvite,
      savingServerIds: savingServerIds ?? this.savingServerIds,
      deletingServerIds: deletingServerIds ?? this.deletingServerIds,
      leavingServerIds: leavingServerIds ?? this.leavingServerIds,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ServerListState &&
            runtimeType == other.runtimeType &&
            status == other.status &&
            listEquals(servers, other.servers) &&
            failure == other.failure &&
            isCreating == other.isCreating &&
            isJoiningInvite == other.isJoiningInvite &&
            setEquals(savingServerIds, other.savingServerIds) &&
            setEquals(deletingServerIds, other.deletingServerIds) &&
            setEquals(leavingServerIds, other.leavingServerIds);
  }

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(servers),
        failure,
        isCreating,
        isJoiningInvite,
        Object.hashAll([...savingServerIds]..sort()),
        Object.hashAll([...deletingServerIds]..sort()),
        Object.hashAll([...leavingServerIds]..sort()),
      );
}
