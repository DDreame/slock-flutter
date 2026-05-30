import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';

/// Characters used to generate random pixel avatar IDs.
const _pixelAvatarIds = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
];

/// Generates a random pixel avatar URL for agent creation.
String generatePixelAvatarUrl([Random? random]) {
  final rng = random ?? Random();
  final id = _pixelAvatarIds[rng.nextInt(_pixelAvatarIds.length)];
  return 'pixel:$id';
}

@immutable
class AgentMutationInput {
  const AgentMutationInput({
    required this.name,
    required this.model,
    required this.runtime,
    required this.machineId,
    this.description,
    this.reasoningEffort,
    this.envVars,
    this.avatarUrl,
    this.onboarding,
  });

  final String name;
  final String? description;
  final String model;
  final String runtime;
  final String? reasoningEffort;
  final String machineId;
  final Map<String, String>? envVars;
  final String? avatarUrl;
  final bool? onboarding;

  Map<String, Object?> toCreateJson() {
    return {
      'name': name,
      'description': _normalizedOptional(description),
      'model': model,
      'runtime': runtime,
      'reasoningEffort': _normalizedOptional(reasoningEffort),
      'machineId': machineId,
      if (envVars != null && envVars!.isNotEmpty) 'envVars': envVars,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (onboarding == true) 'onboarding': true,
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
      if (envVars != null && envVars!.isNotEmpty) 'envVars': envVars,
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
  Future<void> startAgent(String agentId);
  Future<void> stopAgent(String agentId);
  Future<void> resetAgent(String agentId, {required String mode});
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  });
}

abstract class AgentsMutationRepository {
  Future<AgentItem> createAgent(AgentMutationInput input);
  Future<AgentItem> updateAgent(String agentId, AgentMutationInput input);
  Future<void> deleteAgent(String agentId);
}

extension AgentsRepositoryMutationX on AgentsRepository {
  AgentsMutationRepository get _mutationRepository {
    final repository = this;
    if (repository is AgentsMutationRepository) {
      return repository as AgentsMutationRepository;
    }
    throw UnsupportedError('Agent mutation operations are not implemented');
  }

  Future<AgentItem> createAgent(AgentMutationInput input) {
    return _mutationRepository.createAgent(input);
  }

  Future<AgentItem> updateAgent(String agentId, AgentMutationInput input) {
    return _mutationRepository.updateAgent(agentId, input);
  }

  Future<void> deleteAgent(String agentId) {
    return _mutationRepository.deleteAgent(agentId);
  }
}

class AgentActivityLogEntry {
  const AgentActivityLogEntry({required this.timestamp, required this.entry});

  final DateTime timestamp;
  final String entry;
}
