import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/application/machines_state.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';

const _storeLoadTimeout = Duration(seconds: 15);

final machinesStoreProvider =
    AutoDisposeNotifierProvider<MachinesStore, MachinesState>(
  MachinesStore.new,
  dependencies: [currentMachinesServerIdProvider, machinesRepositoryProvider],
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
          .loadMachines()
          .timeout(_storeLoadTimeout);
      state = state.copyWith(
        status: MachinesStatus.success,
        items: _sortMachines(snapshot.items),
        latestDaemonVersion: snapshot.latestDaemonVersion,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(status: MachinesStatus.failure, failure: failure);
    } on TimeoutException {
      state = state.copyWith(
        status: MachinesStatus.failure,
        failure: const TimeoutFailure(
          message: 'Machines loading timed out',
          causeType: 'StoreLoadTimeout',
        ),
      );
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
      latestDaemonVersion: _newerDaemonVersion(
        state.latestDaemonVersion,
        daemonVersion,
      ),
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
  final lowerNames = {for (final m in sorted) m: m.name.toLowerCase()};
  sorted.sort((left, right) {
    final onlineComparison = (right.isOnline ? 1 : 0).compareTo(
      left.isOnline ? 1 : 0,
    );
    if (onlineComparison != 0) {
      return onlineComparison;
    }
    return lowerNames[left]!.compareTo(lowerNames[right]!);
  });
  return sorted;
}

String? _newerDaemonVersion(String? current, String? incoming) {
  if (incoming == null || incoming.isEmpty) return current;
  if (current == null || current.isEmpty) return incoming;
  return _compareVersionStrings(incoming, current) > 0 ? incoming : current;
}

int _compareVersionStrings(String left, String right) {
  final leftParts = _versionParts(left);
  final rightParts = _versionParts(right);
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var index = 0; index < length; index++) {
    final leftPart = index < leftParts.length ? leftParts[index] : 0;
    final rightPart = index < rightParts.length ? rightParts[index] : 0;
    if (leftPart != rightPart) return leftPart.compareTo(rightPart);
  }
  return 0;
}

List<int> _versionParts(String version) {
  final match = RegExp(r'\d+(?:\.\d+)*').firstMatch(version);
  if (match == null) return const [0];
  return match.group(0)!.split('.').map(int.parse).toList(growable: false);
}
