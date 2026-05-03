import 'package:flutter/foundation.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';

/// A group of agents that share the same machine.
@immutable
class AgentMachineGroup {
  const AgentMachineGroup({
    this.machineId,
    required this.machineName,
    required this.machineOnline,
    required this.agents,
  });

  /// The machine ID, or `null` for the
  /// "No Machine Assigned" fallback group.
  final String? machineId;

  /// Display name of the machine, or
  /// "No Machine Assigned" for the fallback group.
  final String machineName;

  /// Whether the underlying machine is currently
  /// online.  Always `false` for the fallback group.
  final bool machineOnline;

  /// Agents in this group, sorted by activity
  /// priority (working first, stopped last).
  final List<AgentItem> agents;

  /// Number of active (non-stopped) agents.
  int get activeCount => agents.where((a) => a.isActive).length;

  /// Total agent count.
  int get totalCount => agents.length;

  /// Whether any agent in the group is active.
  bool get hasActiveAgents => agents.any((a) => a.isActive);

  /// Key used for fold-state persistence.
  /// Uses [machineId] or a fixed sentinel for the
  /// fallback group.
  String get foldKey => machineId ?? _noMachineKey;

  /// One-line summary shown when the section is
  /// collapsed: "Z2 working · S2 working · J1 error".
  String get collapsedSummary =>
      agents.map((a) => '${a.label} ${a.activity}').join(' · ');
}

/// Sentinel key used for the no-machine group in
/// fold-state persistence.
const _noMachineKey = '__no_machine__';

/// Sort priority for agent activity within a machine
/// group.  Lower values sort first.
///
/// Order: working (0) → thinking (1) → error (2) →
///        online (3) → other/offline-active (4) →
///        stopped (5).
int agentActivityPriority(AgentItem agent) {
  if (agent.isStopped) return 5;
  return switch (agent.activity) {
    'working' => 0,
    'thinking' => 1,
    'error' => 2,
    'online' => 3,
    _ => 4,
  };
}

/// Groups [agents] by their [AgentItem.machineId],
/// resolving machine names from [machines].
///
/// Sort rules:
/// - **Groups**: machines with active agents first;
///   ties broken alphabetically by machine name.
///   The "No Machine Assigned" fallback group is
///   always last.
/// - **Within each group**: agents sorted by
///   [agentActivityPriority].
///
/// Agents whose [machineId] does not match any entry
/// in [machines] are placed in a group whose name
/// equals the raw [machineId] string.
List<AgentMachineGroup> groupAgentsByMachine({
  required List<AgentItem> agents,
  required List<MachineItem> machines,
}) {
  if (agents.isEmpty) return const [];

  final machineMap = <String, MachineItem>{
    for (final m in machines) m.id: m,
  };

  // Bucket agents by machineId (null key = no
  // machine).
  final buckets = <String?, List<AgentItem>>{};
  for (final agent in agents) {
    buckets.putIfAbsent(agent.machineId, () => []).add(agent);
  }

  final result = <AgentMachineGroup>[];
  for (final entry in buckets.entries) {
    final machineId = entry.key;
    final groupAgents = [...entry.value]..sort(
        (a, b) => agentActivityPriority(a).compareTo(agentActivityPriority(b)),
      );

    final machine = machineId != null ? machineMap[machineId] : null;

    result.add(AgentMachineGroup(
      machineId: machineId,
      machineName: machineId == null
          ? 'No Machine Assigned'
          : (machine?.name ?? machineId),
      machineOnline: machine?.isOnline ?? false,
      agents: List<AgentItem>.unmodifiable(groupAgents),
    ));
  }

  result.sort((a, b) {
    // "No Machine Assigned" always last.
    if (a.machineId == null && b.machineId != null) {
      return 1;
    }
    if (a.machineId != null && b.machineId == null) {
      return -1;
    }
    // Active-agent groups first.
    final aActive = a.hasActiveAgents ? 0 : 1;
    final bActive = b.hasActiveAgents ? 0 : 1;
    if (aActive != bActive) return aActive - bActive;
    // Alphabetical tie-breaker.
    return a.machineName.compareTo(b.machineName);
  });

  return List<AgentMachineGroup>.unmodifiable(result);
}
