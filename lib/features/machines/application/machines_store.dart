import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/application/machines_state.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';

final machinesStoreProvider =
    AutoDisposeNotifierProvider<MachinesStore, MachinesState>(
      MachinesStore.new,
      dependencies: [currentMachinesServerIdProvider],
    );

class MachinesStore extends AutoDisposeNotifier<MachinesState> {
  @override
  MachinesState build() {
    ref.watch(currentMachinesServerIdProvider);
    return const MachinesState();
  }

  Future<void> ensureLoaded() async {
    if (state.status == MachinesStatus.loading ||
        state.status == MachinesStatus.success) {
      return;
    }
    await load();
  }

  Future<void> load() async {
    state = state.copyWith(status: MachinesStatus.loading, clearFailure: true);

    try {
      final snapshot = await ref
          .read(machinesRepositoryProvider)
          .loadMachines();
      state = state.copyWith(
        status: MachinesStatus.success,
        items: _sortMachines(snapshot.items),
        latestDaemonVersion: snapshot.latestDaemonVersion,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(status: MachinesStatus.failure, failure: failure);
    }
  }

  Future<RegisterMachineResult> registerMachine({required String name}) async {
    state = state.copyWith(isCreating: true, clearFailure: true);

    try {
      final result = await ref
          .read(machinesRepositoryProvider)
          .registerMachine(name: name);
      state = state.copyWith(
        status: MachinesStatus.success,
        isCreating: false,
        items: _sortMachines([...state.items, result.machine]),
        clearFailure: true,
      );
      return result;
    } on AppFailure catch (failure) {
      state = state.copyWith(isCreating: false, failure: failure);
      rethrow;
    }
  }

  Future<void> renameMachine(String machineId, {required String name}) async {
    state = state.copyWith(
      renamingMachineIds: {...state.renamingMachineIds, machineId},
      clearFailure: true,
    );

    try {
      await ref
          .read(machinesRepositoryProvider)
          .renameMachine(machineId, name: name);
      state = state.copyWith(
        items: _sortMachines(
          state.items
              .map(
                (machine) => machine.id == machineId
                    ? machine.copyWith(name: name)
                    : machine,
              )
              .toList(growable: false),
        ),
        renamingMachineIds: {...state.renamingMachineIds}..remove(machineId),
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        renamingMachineIds: {...state.renamingMachineIds}..remove(machineId),
        failure: failure,
      );
      rethrow;
    }
  }

  Future<String> rotateMachineApiKey(String machineId) async {
    state = state.copyWith(
      rotatingKeyMachineIds: {...state.rotatingKeyMachineIds, machineId},
      clearFailure: true,
    );

    try {
      final apiKey = await ref
          .read(machinesRepositoryProvider)
          .rotateMachineApiKey(machineId);
      state = state.copyWith(
        items: state.items
            .map(
              (machine) => machine.id == machineId
                  ? machine.copyWith(apiKeyPrefix: deriveApiKeyPrefix(apiKey))
                  : machine,
            )
            .toList(growable: false),
        rotatingKeyMachineIds: {...state.rotatingKeyMachineIds}
          ..remove(machineId),
        clearFailure: true,
      );
      return apiKey;
    } on AppFailure catch (failure) {
      state = state.copyWith(
        rotatingKeyMachineIds: {...state.rotatingKeyMachineIds}
          ..remove(machineId),
        failure: failure,
      );
      rethrow;
    }
  }

  Future<void> deleteMachine(String machineId) async {
    state = state.copyWith(
      deletingMachineIds: {...state.deletingMachineIds, machineId},
      clearFailure: true,
    );

    try {
      await ref.read(machinesRepositoryProvider).deleteMachine(machineId);
      state = state.copyWith(
        status: MachinesStatus.success,
        items: state.items
            .where((machine) => machine.id != machineId)
            .toList(growable: false),
        deletingMachineIds: {...state.deletingMachineIds}..remove(machineId),
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        deletingMachineIds: {...state.deletingMachineIds}..remove(machineId),
        failure: failure,
      );
      rethrow;
    }
  }

  void updateMachineStatus(
    String machineId,
    String status, {
    int? statusVersion,
  }) {
    state = state.copyWith(
      items: state.items
          .map(
            (machine) => machine.id == machineId
                ? _mergeMachineStatus(
                    machine,
                    status: status,
                    statusVersion: statusVersion,
                  )
                : machine,
          )
          .toList(growable: false),
    );
  }

  void updateMachineCapabilities(
    String machineId, {
    List<String>? runtimes,
    String? hostname,
    String? os,
    String? daemonVersion,
  }) {
    state = state.copyWith(
      items: state.items
          .map(
            (machine) => machine.id == machineId
                ? machine.copyWith(
                    runtimes: runtimes ?? machine.runtimes,
                    hostname: hostname,
                    os: os,
                    daemonVersion: daemonVersion,
                  )
                : machine,
          )
          .toList(growable: false),
      latestDaemonVersion: daemonVersion ?? state.latestDaemonVersion,
    );
  }
}

MachineItem _mergeMachineStatus(
  MachineItem machine, {
  required String status,
  int? statusVersion,
}) {
  final currentVersion = machine.statusVersion;
  if (currentVersion != null &&
      statusVersion != null &&
      statusVersion < currentVersion) {
    return machine;
  }
  return machine.copyWith(
    status: status,
    statusVersion: statusVersion ?? currentVersion,
  );
}

List<MachineItem> _sortMachines(List<MachineItem> items) {
  final sorted = [...items];
  sorted.sort((left, right) {
    final onlineComparison = (right.isOnline ? 1 : 0).compareTo(
      left.isOnline ? 1 : 0,
    );
    if (onlineComparison != 0) {
      return onlineComparison;
    }
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  });
  return sorted;
}
