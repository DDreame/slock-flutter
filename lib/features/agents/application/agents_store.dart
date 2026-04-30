import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';

final agentsStoreProvider =
    NotifierProvider.autoDispose<AgentsStore, AgentsState>(AgentsStore.new);

class AgentsStore extends AutoDisposeNotifier<AgentsState> {
  static const _maxActivityLogEntries = 200;

  @override
  AgentsState build() {
    return const AgentsState();
  }

  Future<void> load() async {
    state = state.copyWith(status: AgentsStatus.loading, clearFailure: true);

    try {
      final repo = ref.read(agentsRepositoryProvider);
      final agents = await repo.listAgents();
      final agentIds = agents.map((agent) => agent.id).toSet();
      state = state.copyWith(
        status: AgentsStatus.success,
        items: agents,
        activityLogs: _pruneActivityLogs(agentIds),
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(status: AgentsStatus.failure, failure: failure);
    }
  }

  Future<AgentItem> createAgent(AgentMutationInput input) async {
    state = state.copyWith(isCreating: true, clearFailure: true);

    try {
      final repo = ref.read(agentsRepositoryProvider);
      final agent = await repo.createAgent(input);
      state = state.copyWith(
        status: AgentsStatus.success,
        items: [...state.items, agent],
        isCreating: false,
        clearFailure: true,
      );
      return agent;
    } on AppFailure catch (failure) {
      state = state.copyWith(isCreating: false, failure: failure);
      rethrow;
    }
  }

  Future<AgentItem> updateAgent(
    String agentId,
    AgentMutationInput input,
  ) async {
    state = state.copyWith(
      savingAgentIds: {...state.savingAgentIds, agentId},
      clearFailure: true,
    );

    try {
      final repo = ref.read(agentsRepositoryProvider);
      final updated = await repo.updateAgent(agentId, input);
      final items = [...state.items];
      final index = items.indexWhere((agent) => agent.id == agentId);
      if (index >= 0) {
        items[index] = updated;
      } else {
        items.add(updated);
      }
      state = state.copyWith(
        status: AgentsStatus.success,
        items: items,
        savingAgentIds: {...state.savingAgentIds}..remove(agentId),
        clearFailure: true,
      );
      return updated;
    } on AppFailure catch (failure) {
      state = state.copyWith(
        savingAgentIds: {...state.savingAgentIds}..remove(agentId),
        failure: failure,
      );
      rethrow;
    }
  }

  Future<void> deleteAgent(String agentId) async {
    state = state.copyWith(
      deletingAgentIds: {...state.deletingAgentIds, agentId},
      clearFailure: true,
    );

    try {
      final repo = ref.read(agentsRepositoryProvider);
      await repo.deleteAgent(agentId);
      final remainingItems =
          state.items.where((agent) => agent.id != agentId).toList();
      state = state.copyWith(
        status: AgentsStatus.success,
        items: remainingItems,
        activityLogs: _pruneActivityLogs(
          remainingItems.map((agent) => agent.id).toSet(),
        ),
        deletingAgentIds: {...state.deletingAgentIds}..remove(agentId),
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        deletingAgentIds: {...state.deletingAgentIds}..remove(agentId),
        failure: failure,
      );
      rethrow;
    }
  }

  Future<void> startAgent(String agentId) async {
    final previousItems = state.items;
    state = state.copyWith(
      controlActionAgentIds: {...state.controlActionAgentIds, agentId},
      items: state.items
          .map(
            (a) => a.id == agentId
                ? a.copyWith(status: 'active', activity: 'working')
                : a,
          )
          .toList(),
    );

    try {
      final repo = ref.read(agentsRepositoryProvider);
      await repo.startAgent(agentId);
    } on AppFailure {
      state = state.copyWith(items: previousItems);
      rethrow;
    } finally {
      state = state.copyWith(
        controlActionAgentIds: {...state.controlActionAgentIds}
          ..remove(agentId),
      );
    }
  }

  Future<void> stopAgent(String agentId) async {
    final previousItems = state.items;
    state = state.copyWith(
      controlActionAgentIds: {...state.controlActionAgentIds, agentId},
      items: state.items
          .map(
            (a) => a.id == agentId
                ? a.copyWith(status: 'stopped', activity: 'offline')
                : a,
          )
          .toList(),
    );

    try {
      final repo = ref.read(agentsRepositoryProvider);
      await repo.stopAgent(agentId);
    } on AppFailure {
      state = state.copyWith(items: previousItems);
      rethrow;
    } finally {
      state = state.copyWith(
        controlActionAgentIds: {...state.controlActionAgentIds}
          ..remove(agentId),
      );
    }
  }

  Future<void> resetAgent(String agentId) async {
    state = state.copyWith(
      controlActionAgentIds: {...state.controlActionAgentIds, agentId},
    );

    try {
      final repo = ref.read(agentsRepositoryProvider);
      await repo.resetAgent(agentId, mode: 'session');
    } on AppFailure {
      rethrow;
    } finally {
      state = state.copyWith(
        controlActionAgentIds: {...state.controlActionAgentIds}
          ..remove(agentId),
      );
    }
  }

  void updateActivity(
    String agentId,
    String activity,
    String? detail, {
    DateTime? timestamp,
  }) {
    final receivedAt = timestamp ?? DateTime.now();
    final entryText = _formatActivityLogEntry(activity, detail);
    final existingLog = state.activityLogFor(agentId);
    final lastEntry = existingLog.isEmpty ? null : existingLog.last;
    final nextLog = lastEntry != null &&
            lastEntry.entry == entryText &&
            receivedAt.difference(lastEntry.timestamp).inMilliseconds < 1000
        ? existingLog
        : [
            ...existingLog,
            AgentActivityLogEntry(timestamp: receivedAt, entry: entryText),
          ]
            .skip(
              existingLog.length + 1 > _maxActivityLogEntries
                  ? existingLog.length + 1 - _maxActivityLogEntries
                  : 0,
            )
            .toList();

    state = state.copyWith(
      items: state.items
          .map(
            (a) => a.id == agentId
                ? a.copyWith(activity: activity, activityDetail: detail ?? '')
                : a,
          )
          .toList(),
      activityLogs: {
        ...state.activityLogs,
        agentId: nextLog,
      },
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
    final remainingItems = state.items.where((a) => a.id != agentId).toList();
    state = state.copyWith(
      items: remainingItems,
      activityLogs: _pruneActivityLogs(
        remainingItems.map((agent) => agent.id).toSet(),
      ),
    );
  }

  void retry() => load();

  Map<String, List<AgentActivityLogEntry>> _pruneActivityLogs(
    Set<String> allowedAgentIds,
  ) {
    if (state.activityLogs.isEmpty) {
      return state.activityLogs;
    }
    return Map<String, List<AgentActivityLogEntry>>.fromEntries(
      state.activityLogs.entries.where(
        (entry) => allowedAgentIds.contains(entry.key),
      ),
    );
  }
}

String _formatActivityLogEntry(String activity, String? detail) {
  final normalizedDetail = detail?.trim();
  final hasDetail = normalizedDetail != null && normalizedDetail.isNotEmpty;
  final activityLabel = switch (activity) {
    'online' => 'Online',
    'thinking' => 'Thinking',
    'working' => 'Working',
    'error' => 'Error',
    'offline' => 'Offline',
    _ => activity,
  };
  if (!hasDetail) {
    return activityLabel;
  }
  return '$activityLabel: $normalizedDetail';
}
