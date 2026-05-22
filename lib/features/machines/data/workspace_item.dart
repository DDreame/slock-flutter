import 'package:flutter/foundation.dart';

@immutable
class WorkspaceItem {
  const WorkspaceItem({
    required this.id,
    required this.name,
    required this.machineId,
    required this.createdAt,
    this.path,
    this.agentId,
    this.agentName,
    this.status = 'active',
  });

  final String id;
  final String name;
  final String machineId;
  final DateTime createdAt;
  final String? path;
  final String? agentId;
  final String? agentName;
  final String status;

  bool get isActive => status == 'active';

  WorkspaceItem copyWith({
    String? name,
    String? path,
    bool clearPath = false,
    String? agentId,
    bool clearAgentId = false,
    String? agentName,
    bool clearAgentName = false,
    String? status,
  }) {
    return WorkspaceItem(
      id: id,
      name: name ?? this.name,
      machineId: machineId,
      createdAt: createdAt,
      path: clearPath ? null : (path ?? this.path),
      agentId: clearAgentId ? null : (agentId ?? this.agentId),
      agentName: clearAgentName ? null : (agentName ?? this.agentName),
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          machineId == other.machineId &&
          createdAt == other.createdAt &&
          path == other.path &&
          agentId == other.agentId &&
          agentName == other.agentName &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        machineId,
        createdAt,
        path,
        agentId,
        agentName,
        status,
      );
}
