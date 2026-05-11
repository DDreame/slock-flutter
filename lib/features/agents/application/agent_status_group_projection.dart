import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/agents/application/agent_status_group.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';

/// Reactive projection of agents grouped by display status.
///
/// Both the Home agent card and AgentsPage consume this provider
/// to render status-first grouped displays ("A、B 思考中").
///
/// Returns empty list when [agentsStoreProvider] is not yet loaded.
final agentStatusGroupProjectionProvider =
    Provider.autoDispose<List<AgentStatusGroup>>((ref) {
  final agentsState = ref.watch(agentsStoreProvider);

  if (agentsState.status != AgentsStatus.success) {
    return const [];
  }

  return groupAgentsByStatus(agentsState.items);
});
