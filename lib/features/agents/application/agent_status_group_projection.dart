import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/agents/application/agent_status_group.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';

/// Reactive projection of agents grouped by display status.
///
/// Both the Home agent card and AgentsPage consume this provider
/// to render status-first grouped displays ("A、B 思考中").
///
/// INV-AGENTS-PROJECTION-SELECT-1: Only watches (status, items) from the
/// agents store. activityLogs, savingAgentIds, etc. do not trigger recomputation.
///
/// Returns empty list when [agentsStoreProvider] is not yet loaded.
final agentStatusGroupProjectionProvider =
    Provider.autoDispose<List<AgentStatusGroup>>((ref) {
  final (:status, :items) = ref.watch(
    agentsStoreProvider.select((s) => (status: s.status, items: s.items)),
  );

  if (status != AgentsStatus.success) {
    return const [];
  }

  return groupAgentsByStatus(items);
});
