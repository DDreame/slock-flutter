import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';

enum AgentsStatus { initial, loading, success, failure }

@immutable
class AgentsState {
  const AgentsState({
    this.status = AgentsStatus.initial,
    this.items = const [],
    this.failure,
    this.isCreating = false,
    this.savingAgentIds = const <String>{},
    this.deletingAgentIds = const <String>{},
  });

  final AgentsStatus status;
  final List<AgentItem> items;
  final AppFailure? failure;
  final bool isCreating;
  final Set<String> savingAgentIds;
  final Set<String> deletingAgentIds;

  bool isSaving(String agentId) => savingAgentIds.contains(agentId);
  bool isDeleting(String agentId) => deletingAgentIds.contains(agentId);
  bool isBusy(String agentId) => isSaving(agentId) || isDeleting(agentId);

  AgentsState copyWith({
    AgentsStatus? status,
    List<AgentItem>? items,
    AppFailure? failure,
    bool? isCreating,
    Set<String>? savingAgentIds,
    Set<String>? deletingAgentIds,
    bool clearFailure = false,
  }) {
    return AgentsState(
      status: status ?? this.status,
      items: items ?? this.items,
      failure: clearFailure ? null : (failure ?? this.failure),
      isCreating: isCreating ?? this.isCreating,
      savingAgentIds: savingAgentIds ?? this.savingAgentIds,
      deletingAgentIds: deletingAgentIds ?? this.deletingAgentIds,
    );
  }
}
