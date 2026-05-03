import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';

enum AgentsStatus { initial, loading, success, failure }

@immutable
class AgentsState {
  const AgentsState({
    this.status = AgentsStatus.initial,
    this.items = const [],
    this.machines = const [],
    this.activityLogs = const <String, List<AgentActivityLogEntry>>{},
    this.failure,
    this.isCreating = false,
    this.savingAgentIds = const <String>{},
    this.deletingAgentIds = const <String>{},
    this.controlActionAgentIds = const <String>{},
  });

  final AgentsStatus status;
  final List<AgentItem> items;
  final List<MachineItem> machines;
  final Map<String, List<AgentActivityLogEntry>> activityLogs;
  final AppFailure? failure;
  final bool isCreating;
  final Set<String> savingAgentIds;
  final Set<String> deletingAgentIds;
  final Set<String> controlActionAgentIds;

  bool isSaving(String agentId) => savingAgentIds.contains(agentId);
  bool isDeleting(String agentId) => deletingAgentIds.contains(agentId);
  bool isControlActionInFlight(String agentId) =>
      controlActionAgentIds.contains(agentId);
  bool isBusy(String agentId) =>
      isSaving(agentId) ||
      isDeleting(agentId) ||
      isControlActionInFlight(agentId);
  List<AgentActivityLogEntry> activityLogFor(String agentId) =>
      activityLogs[agentId] ?? const <AgentActivityLogEntry>[];

  AgentsState copyWith({
    AgentsStatus? status,
    List<AgentItem>? items,
    List<MachineItem>? machines,
    Map<String, List<AgentActivityLogEntry>>? activityLogs,
    AppFailure? failure,
    bool? isCreating,
    Set<String>? savingAgentIds,
    Set<String>? deletingAgentIds,
    Set<String>? controlActionAgentIds,
    bool clearFailure = false,
  }) {
    return AgentsState(
      status: status ?? this.status,
      items: items ?? this.items,
      machines: machines ?? this.machines,
      activityLogs: activityLogs ?? this.activityLogs,
      failure: clearFailure ? null : (failure ?? this.failure),
      isCreating: isCreating ?? this.isCreating,
      savingAgentIds: savingAgentIds ?? this.savingAgentIds,
      deletingAgentIds: deletingAgentIds ?? this.deletingAgentIds,
      controlActionAgentIds:
          controlActionAgentIds ?? this.controlActionAgentIds,
    );
  }
}
