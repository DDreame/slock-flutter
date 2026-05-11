import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';

/// Shared fake [AgentsRepository] for tests.
///
/// By default returns an empty list. Supports failure injection
/// and CRUD tracking via [AgentsMutationRepository].
class FakeAgentsRepository
    implements AgentsRepository, AgentsMutationRepository {
  FakeAgentsRepository({
    this.agents = const [],
    this.shouldFail = false,
    this.activityLogShouldFail = false,
  });

  List<AgentItem> agents;
  bool shouldFail;
  bool activityLogShouldFail;

  final List<AgentMutationInput> createRequests = [];
  final List<(String, AgentMutationInput)> updateRequests = [];
  final List<String> deletedAgentIds = [];
  final List<String> startedAgentIds = [];
  final List<String> stoppedAgentIds = [];
  final List<String> resetAgentIds = [];
  int listAgentsCalls = 0;

  @override
  Future<List<AgentItem>> listAgents() async {
    listAgentsCalls++;
    if (shouldFail) throw const UnknownFailure(message: 'Failed to load');
    return agents;
  }

  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async {
    createRequests.add(input);
    if (shouldFail) throw const UnknownFailure(message: 'Failed to create');
    return AgentItem(
      id: 'agent-${createRequests.length}',
      name: input.name,
      model: input.model,
      runtime: input.runtime,
      status: 'stopped',
      activity: 'offline',
    );
  }

  @override
  Future<AgentItem> updateAgent(
    String agentId,
    AgentMutationInput input,
  ) async {
    updateRequests.add((agentId, input));
    if (shouldFail) throw const UnknownFailure(message: 'Failed to update');
    return AgentItem(
      id: agentId,
      name: input.name,
      model: input.model,
      runtime: input.runtime,
      status: 'stopped',
      activity: 'offline',
    );
  }

  @override
  Future<void> deleteAgent(String agentId) async {
    deletedAgentIds.add(agentId);
    if (shouldFail) throw const UnknownFailure(message: 'Failed to delete');
  }

  @override
  Future<void> startAgent(String agentId) async {
    startedAgentIds.add(agentId);
    if (shouldFail) throw const UnknownFailure(message: 'Failed to start');
  }

  @override
  Future<void> stopAgent(String agentId) async {
    stoppedAgentIds.add(agentId);
    if (shouldFail) throw const UnknownFailure(message: 'Failed to stop');
  }

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {
    resetAgentIds.add(agentId);
    if (shouldFail) throw const UnknownFailure(message: 'Failed to reset');
  }

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async {
    if (activityLogShouldFail) {
      throw const UnknownFailure(message: 'Failed to load activity log');
    }
    return const [];
  }
}
