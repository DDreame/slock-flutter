import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';

export 'package:slock_app/features/agents/data/agents_repository.dart'
    show RuntimeModelsResult, RuntimeModelOption;

// ---------------------------------------------------------------------------
// Load machines for a given server (agent form context).
// ---------------------------------------------------------------------------

/// Loads the machines list for a given [serverId].
///
/// Used by [AgentFormDialog] to populate the machine selector.
/// Delegates to [AgentFormRepository.loadFormMachines].
final agentFormLoadMachinesUseCaseProvider =
    Provider<Future<MachinesSnapshot> Function(String serverId)>((ref) {
  return (String serverId) async {
    final repo = ref.read(agentFormRepositoryProvider);
    return repo.loadFormMachines(serverId);
  };
});

// ---------------------------------------------------------------------------
// Load runtime models for a machine + runtime pair.
// ---------------------------------------------------------------------------

/// Loads available models for a specific [runtime] on [machineId] within
/// [serverId].
///
/// Returns a structured [RuntimeModelsResult] with parsed model options.
/// Delegates to [AgentFormRepository.loadRuntimeModels].
final agentFormLoadRuntimeModelsUseCaseProvider = Provider<
    Future<RuntimeModelsResult> Function({
      required String serverId,
      required String machineId,
      required String runtime,
    })>((ref) {
  return ({
    required String serverId,
    required String machineId,
    required String runtime,
  }) async {
    final repo = ref.read(agentFormRepositoryProvider);
    return repo.loadRuntimeModels(
      serverId: serverId,
      machineId: machineId,
      runtime: runtime,
    );
  };
});
