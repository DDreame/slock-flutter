import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';

enum MachinesStatus { initial, loading, success, failure }

@immutable
class MachinesState {
  const MachinesState({
    this.status = MachinesStatus.initial,
    this.items = const [],
    this.latestDaemonVersion,
    this.failure,
    this.isCreating = false,
    this.renamingMachineIds = const <String>{},
    this.rotatingKeyMachineIds = const <String>{},
    this.deletingMachineIds = const <String>{},
  });

  final MachinesStatus status;
  final List<MachineItem> items;
  final String? latestDaemonVersion;
  final AppFailure? failure;
  final bool isCreating;
  final Set<String> renamingMachineIds;
  final Set<String> rotatingKeyMachineIds;
  final Set<String> deletingMachineIds;

  bool isRenaming(String machineId) => renamingMachineIds.contains(machineId);

  bool isRotatingKey(String machineId) =>
      rotatingKeyMachineIds.contains(machineId);

  bool isDeleting(String machineId) => deletingMachineIds.contains(machineId);

  bool isBusy(String machineId) =>
      isRenaming(machineId) ||
      isRotatingKey(machineId) ||
      isDeleting(machineId);

  MachinesState copyWith({
    MachinesStatus? status,
    List<MachineItem>? items,
    String? latestDaemonVersion,
    bool clearLatestDaemonVersion = false,
    AppFailure? failure,
    bool clearFailure = false,
    bool? isCreating,
    Set<String>? renamingMachineIds,
    Set<String>? rotatingKeyMachineIds,
    Set<String>? deletingMachineIds,
  }) {
    return MachinesState(
      status: status ?? this.status,
      items: items ?? this.items,
      latestDaemonVersion: clearLatestDaemonVersion
          ? null
          : (latestDaemonVersion ?? this.latestDaemonVersion),
      failure: clearFailure ? null : (failure ?? this.failure),
      isCreating: isCreating ?? this.isCreating,
      renamingMachineIds: renamingMachineIds ?? this.renamingMachineIds,
      rotatingKeyMachineIds:
          rotatingKeyMachineIds ?? this.rotatingKeyMachineIds,
      deletingMachineIds: deletingMachineIds ?? this.deletingMachineIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MachinesState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          listEquals(items, other.items) &&
          latestDaemonVersion == other.latestDaemonVersion &&
          failure == other.failure &&
          isCreating == other.isCreating &&
          setEquals(renamingMachineIds, other.renamingMachineIds) &&
          setEquals(rotatingKeyMachineIds, other.rotatingKeyMachineIds) &&
          setEquals(deletingMachineIds, other.deletingMachineIds);

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(items),
        latestDaemonVersion,
        failure,
        isCreating,
        Object.hashAll(renamingMachineIds),
        Object.hashAll(rotatingKeyMachineIds),
        Object.hashAll(deletingMachineIds),
      );
}
