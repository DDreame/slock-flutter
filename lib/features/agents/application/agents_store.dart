import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';

final agentsStoreProvider =
    NotifierProvider<AgentsStore, AgentsState>(AgentsStore.new);

class AgentsStore extends Notifier<AgentsState> {
  static const _maxActivityLogEntries = 200;

  /// Completer-based guard for ensureLoaded — prevents concurrent
  /// callers from each firing a separate load() call (#726).
  Completer<void>? _ensureLoadedCompleter;

  bool _disposed = false;

  @override
  AgentsState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    // INV-834: Re-fetch on WebSocket reconnect — data may be stale.
    ref.listen(realtimeServiceProvider.select((s) => s.status), (prev, next) {
      if (prev == RealtimeConnectionStatus.reconnecting &&
          next == RealtimeConnectionStatus.connected) {
        if (state.status == AgentsStatus.success) {
          load();
        }
      }
    });

    return const AgentsState();
  }

  Future<void> load() async {
    if (_disposed) return;
    final hasStaleData = state.status == AgentsStatus.success;

    if (hasStaleData) {
      // SWR: keep status=success, signal refresh via isRefreshing.
      state = state.copyWith(
        isRefreshing: true,
        clearFailure: true,
      );
    } else {
      state = state.copyWith(
        status: AgentsStatus.loading,
        clearFailure: true,
      );
    }

    try {
      final repo = ref.read(agentsRepositoryProvider);
      final loadMachines = ref.read(agentsMachinesLoaderProvider);

      // Fetch agents and machines in parallel.
      final results = await Future.wait([
        repo.listAgents(),
        loadMachines(),
      ]);

      if (_disposed) return;

      final agents = results[0] as List<AgentItem>;
      final machines = results[1] as List<MachineItem>;
      final agentIds = agents.map((agent) => agent.id).toSet();

      state = state.copyWith(
        status: AgentsStatus.success,
        items: agents,
        machines: machines,
        activityLogs: _pruneActivityLogs(agentIds),
        isRefreshing: false,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (_disposed) return;
      if (hasStaleData) {
        // SWR: preserve success status, surface error as overlay.
        state = state.copyWith(
          isRefreshing: false,
          failure: failure,
        );
      } else {
        state = state.copyWith(
          status: AgentsStatus.failure,
          failure: failure,
        );
      }
    } catch (error, stackTrace) {
      if (_disposed) return;
      _captureUnexpectedError(
        error,
        stackTrace,
        operation: 'AgentsStore.load',
      );
      final failure = _unexpectedFailure(
        error,
        message: 'Failed to load agents.',
      );
      if (hasStaleData) {
        state = state.copyWith(isRefreshing: false, failure: failure);
      } else {
        state = state.copyWith(
          status: AgentsStatus.failure,
          failure: failure,
        );
      }
    }
  }

  Future<AgentItem> createAgent(AgentMutationInput input) async {
    state = state.copyWith(isCreating: true, clearFailure: true);

    try {
      final repo = ref.read(agentsRepositoryProvider);
      final agent = await repo.createAgent(input);
      if (_disposed) return agent;
      state = state.copyWith(
        status: AgentsStatus.success,
        items: [...state.items, agent],
        isCreating: false,
        clearFailure: true,
      );
      return agent;
    } on AppFailure catch (failure) {
      if (_disposed) rethrow;
      state = state.copyWith(isCreating: false, failure: failure);
      rethrow;
    } catch (error, stackTrace) {
      if (_disposed) rethrow;
      _captureUnexpectedError(
        error,
        stackTrace,
        operation: 'AgentsStore.createAgent',
      );
      final failure = _unexpectedFailure(
        error,
        message: 'Failed to create agent.',
      );
      state = state.copyWith(isCreating: false, failure: failure);
      throw failure;
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
      if (_disposed) return updated;
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
      if (_disposed) rethrow;
      state = state.copyWith(
        savingAgentIds: {...state.savingAgentIds}..remove(agentId),
        failure: failure,
      );
      rethrow;
    } catch (error, stackTrace) {
      if (_disposed) rethrow;
      _captureUnexpectedError(
        error,
        stackTrace,
        operation: 'AgentsStore.updateAgent',
      );
      final failure = _unexpectedFailure(
        error,
        message: 'Failed to update agent.',
      );
      state = state.copyWith(
        savingAgentIds: {...state.savingAgentIds}..remove(agentId),
        failure: failure,
      );
      throw failure;
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
      if (_disposed) return;
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
      if (_disposed) rethrow;
      state = state.copyWith(
        deletingAgentIds: {...state.deletingAgentIds}..remove(agentId),
        failure: failure,
      );
      rethrow;
    } catch (error, stackTrace) {
      if (_disposed) rethrow;
      _captureUnexpectedError(
        error,
        stackTrace,
        operation: 'AgentsStore.deleteAgent',
      );
      final failure = _unexpectedFailure(
        error,
        message: 'Failed to delete agent.',
      );
      state = state.copyWith(
        deletingAgentIds: {...state.deletingAgentIds}..remove(agentId),
        failure: failure,
      );
      throw failure;
    }
  }

  Future<void> startAgent(String agentId) async {
    // INV-841: Safe lookup — concurrent removeAgent event may have already
    // removed this agent from state. Bail out instead of crashing.
    final index = state.items.indexWhere((a) => a.id == agentId);
    if (index < 0) return;
    final previousItem = state.items[index];
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
      if (_disposed) return;
      state = state.copyWith(
        items:
            state.items.map((a) => a.id == agentId ? previousItem : a).toList(),
      );
      rethrow;
    } catch (error, stackTrace) {
      if (_disposed) return;
      _captureUnexpectedError(
        error,
        stackTrace,
        operation: 'AgentsStore.startAgent',
      );
      final failure = _unexpectedFailure(
        error,
        message: 'Failed to start agent.',
      );
      state = state.copyWith(
        items:
            state.items.map((a) => a.id == agentId ? previousItem : a).toList(),
        failure: failure,
      );
      throw failure;
    } finally {
      if (!_disposed) {
        state = state.copyWith(
          controlActionAgentIds: {...state.controlActionAgentIds}
            ..remove(agentId),
        );
      }
    }
  }

  Future<void> stopAgent(String agentId) async {
    // INV-841: Safe lookup — concurrent removeAgent event may have already
    // removed this agent from state. Bail out instead of crashing.
    final index = state.items.indexWhere((a) => a.id == agentId);
    if (index < 0) return;
    final previousItem = state.items[index];
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
      if (_disposed) return;
      state = state.copyWith(
        items:
            state.items.map((a) => a.id == agentId ? previousItem : a).toList(),
      );
      rethrow;
    } catch (error, stackTrace) {
      if (_disposed) return;
      _captureUnexpectedError(
        error,
        stackTrace,
        operation: 'AgentsStore.stopAgent',
      );
      final failure = _unexpectedFailure(
        error,
        message: 'Failed to stop agent.',
      );
      state = state.copyWith(
        items:
            state.items.map((a) => a.id == agentId ? previousItem : a).toList(),
        failure: failure,
      );
      throw failure;
    } finally {
      if (!_disposed) {
        state = state.copyWith(
          controlActionAgentIds: {...state.controlActionAgentIds}
            ..remove(agentId),
        );
      }
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
      if (_disposed) return;
      rethrow;
    } finally {
      if (!_disposed) {
        state = state.copyWith(
          controlActionAgentIds: {...state.controlActionAgentIds}
            ..remove(agentId),
        );
      }
    }
  }

  void updateActivity(
    String agentId,
    String activity,
    String? detail, {
    DateTime? timestamp,
  }) {
    final receivedAt = timestamp ?? DateTime.now();
    final l10n = ref.read(appLocalizationsProvider);
    final entryText = _formatActivityLogEntry(activity, detail, l10n);
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

  /// Idempotent load trigger — only fires [load] when the store has not yet
  /// loaded (status == initial). Safe to call from multiple entry points
  /// (initState, ref.listen callbacks) without risking duplicate requests.
  ///
  /// Uses a Completer guard so concurrent callers await the same in-flight
  /// load rather than each spawning their own (#726).
  Future<void> ensureLoaded() async {
    if (state.status != AgentsStatus.initial) return;
    if (_ensureLoadedCompleter != null) {
      return _ensureLoadedCompleter!.future;
    }
    _ensureLoadedCompleter = Completer<void>();
    try {
      await load();
      _ensureLoadedCompleter!.complete();
    } catch (e, s) {
      _ensureLoadedCompleter!.completeError(e, s);
    } finally {
      _ensureLoadedCompleter = null;
    }
  }

  void retry() => load();

  /// Loads historical activity log entries from REST for [agentId]
  /// and merges them with any live entries already captured.
  Future<void> loadActivityLog(String agentId) async {
    if (_disposed) return;
    try {
      final repo = ref.read(agentsRepositoryProvider);
      final historical = await repo.getActivityLog(agentId);
      if (_disposed) return;
      final existing = state.activityLogFor(agentId);
      final merged = _mergeActivityLogs(historical, existing);
      state = state.copyWith(
        activityLogs: {...state.activityLogs, agentId: merged},
      );
    } on AppFailure catch (_) {
      // Silently fail — live events still work.
    }
  }

  List<AgentActivityLogEntry> _mergeActivityLogs(
    List<AgentActivityLogEntry> historical,
    List<AgentActivityLogEntry> live,
  ) {
    final all = [...historical, ...live];
    all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final seen = <String>{};
    final deduped = <AgentActivityLogEntry>[];
    for (final entry in all) {
      final key = '${entry.timestamp.millisecondsSinceEpoch}:${entry.entry}';
      if (seen.add(key)) deduped.add(entry);
    }
    if (deduped.length > _maxActivityLogEntries) {
      return deduped.sublist(deduped.length - _maxActivityLogEntries);
    }
    return deduped;
  }

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

  void _captureUnexpectedError(
    Object error,
    StackTrace stackTrace, {
    required String operation,
  }) {
    try {
      ref.read(diagnosticsCollectorProvider).error(
        'AgentsStore',
        '$operation failed: $error',
        metadata: {'stackTrace': stackTrace.toString()},
      );
    } catch (_) {}
  }

  AppFailure _unexpectedFailure(Object error, {required String message}) {
    return UnknownFailure(
      message: message,
      causeType: error.runtimeType.toString(),
    );
  }
}

String _formatActivityLogEntry(
  String activity,
  String? detail,
  AppLocalizations l10n,
) {
  final normalizedDetail = detail?.trim();
  final hasDetail = normalizedDetail != null && normalizedDetail.isNotEmpty;
  final activityLabel = switch (activity) {
    'online' => l10n.agentsActivityOnline,
    'thinking' => l10n.agentsActivityThinking,
    'working' => l10n.agentsActivityWorking,
    'error' => hasDetail
        ? l10n.agentsActivityErrorDetail(normalizedDetail)
        : l10n.agentsActivityError,
    'offline' => l10n.agentsActivityOffline,
    _ => activity,
  };
  // For 'error' with detail, the label already includes ": detail".
  if (activity == 'error' && hasDetail) {
    return activityLabel;
  }
  if (!hasDetail) {
    return activityLabel;
  }
  return '$activityLabel: $normalizedDetail';
}
