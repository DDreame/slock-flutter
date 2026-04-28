import 'package:flutter/foundation.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';

@immutable
class AgentMutationInput {
  const AgentMutationInput({
    required this.name,
    required this.model,
    required this.runtime,
    required this.machineId,
    this.description,
    this.reasoningEffort,
  });

  final String name;
  final String? description;
  final String model;
  final String runtime;
  final String? reasoningEffort;
  final String machineId;

  Map<String, Object?> toCreateJson() {
    return {
      'name': name,
      'description': _normalizedOptional(description),
      'model': model,
      'runtime': runtime,
      'reasoningEffort': _normalizedOptional(reasoningEffort),
      'machineId': machineId,
    }..removeWhere((_, value) => value == null);
  }

  Map<String, Object?> toUpdateJson() {
    return {
      'name': name,
      'description': _normalizedOptional(description),
      'model': model,
      'runtime': runtime,
      'reasoningEffort': _normalizedOptional(reasoningEffort),
      'machineId': machineId,
    };
  }

  String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

abstract class AgentsRepository {
  Future<List<AgentItem>> listAgents();
  Future<AgentItem> createAgent(AgentMutationInput input);
  Future<AgentItem> updateAgent(String agentId, AgentMutationInput input);
  Future<void> deleteAgent(String agentId);
  Future<void> startAgent(String agentId);
  Future<void> stopAgent(String agentId);
  Future<void> resetAgent(String agentId, {required String mode});
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  });
}

class AgentActivityLogEntry {
  const AgentActivityLogEntry({required this.timestamp, required this.entry});

  final DateTime timestamp;
  final String entry;
}
