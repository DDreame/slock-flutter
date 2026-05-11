import 'package:flutter/foundation.dart';
import 'package:slock_app/features/agents/application/agent_display_status.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';

/// A group of agents that share the same [AgentDisplayStatus].
///
/// Used by both the Home agent card and AgentsPage to render
/// status-first grouped displays ("A、B 思考中").
@immutable
class AgentStatusGroup {
  AgentStatusGroup({
    required this.displayStatus,
    required List<AgentItem> agents,
  }) : agents = List<AgentItem>.unmodifiable(agents);

  final AgentDisplayStatus displayStatus;
  final List<AgentItem> agents;

  /// Number of agents in this group.
  int get count => agents.length;

  /// Persistence key for fold state.
  String get foldKey => 'status:${displayStatus.name}';

  /// Whether this group represents active agents
  /// (not offline or stopped).
  bool get isActive =>
      displayStatus != AgentDisplayStatus.offline &&
      displayStatus != AgentDisplayStatus.stopped;

  /// Merged summary string: "A、B 思考中".
  ///
  /// Agent labels joined with `、` (Chinese enumeration comma),
  /// followed by the status label.
  String get mergedSummary {
    final names = agents.map((a) => a.label).join('、');
    final label = displayStatusLabel(displayStatus);
    return '$names $label';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentStatusGroup &&
          runtimeType == other.runtimeType &&
          displayStatus == other.displayStatus &&
          listEquals(agents, other.agents);

  @override
  int get hashCode => Object.hash(displayStatus, Object.hashAll(agents));
}

/// Groups [agents] by their resolved [AgentDisplayStatus].
///
/// Sort rules:
/// - **Groups**: sorted by status priority
///   (thinking → working → error → online → offline → stopped).
/// - **Within each group**: agents sorted alphabetically by label.
List<AgentStatusGroup> groupAgentsByStatus(List<AgentItem> agents) {
  if (agents.isEmpty) return const [];

  final buckets = <AgentDisplayStatus, List<AgentItem>>{};
  for (final agent in agents) {
    final status = resolveDisplayStatus(agent);
    buckets.putIfAbsent(status, () => []).add(agent);
  }

  final result = <AgentStatusGroup>[];
  for (final entry in buckets.entries) {
    final sorted = [...entry.value]..sort((a, b) => a.label.compareTo(b.label));
    result.add(AgentStatusGroup(
      displayStatus: entry.key,
      agents: sorted,
    ));
  }

  result.sort(
    (a, b) => displayStatusPriority(a.displayStatus)
        .compareTo(displayStatusPriority(b.displayStatus)),
  );

  return List<AgentStatusGroup>.unmodifiable(result);
}
