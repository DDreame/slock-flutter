import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';

final agentsStoreProvider =
    NotifierProvider.autoDispose<AgentsStore, AgentsState>(AgentsStore.new);

class AgentsStore extends AutoDisposeNotifier<AgentsState> {
  @override
  AgentsState build() {
    return const AgentsState();
  }

  Future<void> load() async {
    state = state.copyWith(
      status: AgentsStatus.loading,
      clearFailure: true,
    );

    try {
      final repo = ref.read(agentsRepositoryProvider);
      final agents = await repo.listAgents();
      state = state.copyWith(
        status: AgentsStatus.success,
        items: agents,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        status: AgentsStatus.failure,
        failure: failure,
      );
    }
  }

  Future<void> startAgent(String agentId) async {
    final previousItems = state.items;
    state = state.copyWith(
      items: state.items
          .map((a) => a.id == agentId
              ? a.copyWith(status: 'active', activity: 'working')
              : a)
          .toList(),
    );

    try {
      final repo = ref.read(agentsRepositoryProvider);
      await repo.startAgent(agentId);
    } on AppFailure {
      state = state.copyWith(items: previousItems);
      rethrow;
    }
  }

  Future<void> stopAgent(String agentId) async {
    final previousItems = state.items;
    state = state.copyWith(
      items: state.items
          .map((a) => a.id == agentId
              ? a.copyWith(status: 'stopped', activity: 'offline')
              : a)
          .toList(),
    );

    try {
      final repo = ref.read(agentsRepositoryProvider);
      await repo.stopAgent(agentId);
    } on AppFailure {
      state = state.copyWith(items: previousItems);
      rethrow;
    }
  }

  Future<void> resetAgent(String agentId) async {
    try {
      final repo = ref.read(agentsRepositoryProvider);
      await repo.resetAgent(agentId, mode: 'session');
    } on AppFailure {
      rethrow;
    }
  }

  void updateActivity(String agentId, String activity, String? detail) {
    state = state.copyWith(
      items: state.items
          .map((a) => a.id == agentId
              ? a.copyWith(activity: activity, activityDetail: detail ?? '')
              : a)
          .toList(),
    );
  }

  void upsertAgent(AgentItem agent) {
    final index = state.items.indexWhere((a) => a.id == agent.id);
    if (index >= 0) {
      final updated = [...state.items];
      updated[index] = agent;
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [...state.items, agent]);
    }
  }

  void removeAgent(String agentId) {
    state = state.copyWith(
      items: state.items.where((a) => a.id != agentId).toList(),
    );
  }

  void retry() => load();
}
