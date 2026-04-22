import 'package:slock_app/features/agents/data/agent_item.dart';

abstract class AgentsRepository {
  Future<List<AgentItem>> listAgents();
  Future<AgentItem> startAgent(String agentId);
  Future<AgentItem> stopAgent(String agentId);
  Future<AgentItem> resetAgent(String agentId, {required String mode});
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  });
}

class AgentActivityLogEntry {
  const AgentActivityLogEntry({
    required this.timestamp,
    required this.entry,
  });

  final DateTime timestamp;
  final String entry;
}
