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
    this.isRefreshing = false,
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
  final bool isRefreshing;
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          listEquals(items, other.items) &&
          listEquals(machines, other.machines) &&
          _mapOfListsEquals(activityLogs, other.activityLogs) &&
          failure == other.failure &&
          isRefreshing == other.isRefreshing &&
          isCreating == other.isCreating &&
          setEquals(savingAgentIds, other.savingAgentIds) &&
          setEquals(deletingAgentIds, other.deletingAgentIds) &&
          setEquals(controlActionAgentIds, other.controlActionAgentIds);

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(items),
        Object.hashAll(machines),
        Object.hashAll(activityLogs.entries),
        failure,
        isRefreshing,
        isCreating,
        Object.hashAll(savingAgentIds),
        Object.hashAll(deletingAgentIds),
        Object.hashAll(controlActionAgentIds),
      );

  /// Deep equality for Map<String, List<T>> using listEquals per entry.
  static bool _mapOfListsEquals<T>(
    Map<String, List<T>> a,
    Map<String, List<T>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !listEquals(a[key], b[key])) return false;
    }
    return true;
  }

  AgentsState copyWith({
    AgentsStatus? status,
    List<AgentItem>? items,
    List<MachineItem>? machines,
    Map<String, List<AgentActivityLogEntry>>? activityLogs,
    AppFailure? failure,
    bool? isRefreshing,
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
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isCreating: isCreating ?? this.isCreating,
      savingAgentIds: savingAgentIds ?? this.savingAgentIds,
      deletingAgentIds: deletingAgentIds ?? this.deletingAgentIds,
      controlActionAgentIds:
          controlActionAgentIds ?? this.controlActionAgentIds,
    );
  }
}
