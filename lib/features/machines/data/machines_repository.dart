import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';

@immutable
class MachinesSnapshot {
  const MachinesSnapshot({this.items = const [], this.latestDaemonVersion});

  final List<MachineItem> items;
  final String? latestDaemonVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MachinesSnapshot &&
          runtimeType == other.runtimeType &&
          listEquals(items, other.items) &&
          latestDaemonVersion == other.latestDaemonVersion;

  @override
  int get hashCode => Object.hash(Object.hashAll(items), latestDaemonVersion);
}

@immutable
class RegisterMachineResult {
  const RegisterMachineResult({required this.machine, required this.apiKey});

  final MachineItem machine;
  final String apiKey;
}

abstract class MachinesRepository {
  Future<MachinesSnapshot> loadMachines();

  Future<RegisterMachineResult> registerMachine({required String name});

  Future<void> renameMachine(String machineId, {required String name});

  Future<String> rotateMachineApiKey(String machineId);

  Future<void> deleteMachine(String machineId);
}

MachinesSnapshot parseMachinesSnapshot(Object? payload) {
  final root = _readMap(payload);
  if (root == null) {
    return const MachinesSnapshot();
  }

  final rawMachines = root['machines'];
  final items = rawMachines is List
      ? rawMachines
            .map(_readMap)
            .whereType<Map<String, dynamic>>()
            .map(parseMachineItem)
            .toList(growable: false)
      : payload is List
      ? payload
            .map(_readMap)
            .whereType<Map<String, dynamic>>()
            .map(parseMachineItem)
            .toList(growable: false)
      : const <MachineItem>[];

  return MachinesSnapshot(
    items: items,
    latestDaemonVersion: _firstPresentString(
      root,
      fields: const ['latestDaemonVersion', 'daemonVersion'],
    ),
  );
}

RegisterMachineResult parseRegisterMachineResult(Object? payload) {
  final root = _readMap(payload) ?? const <String, dynamic>{};
  final machineMap = _readMap(root['machine']) ?? root;
  final apiKey = _firstPresentString(
    root,
    fields: const ['apiKey', 'machineApiKey'],
  );

  return RegisterMachineResult(
    machine: parseMachineItem(machineMap).copyWith(
      apiKeyPrefix: apiKey != null ? deriveApiKeyPrefix(apiKey) : null,
    ),
    apiKey: apiKey ?? '',
  );
}

String readApiKeyFromPayload(Object? payload) {
  final root = _readMap(payload);
  return _firstPresentString(root, fields: const ['apiKey', 'machineApiKey']) ??
      '';
}

MachineItem parseMachineItem(Map<String, dynamic> map) {
  final capabilities = _readMap(map['capabilities']);
  final runtimes =
      _readStringList(map['runtimes']) ??
      _readStringList(capabilities?['runtimes']) ??
      const <String>[];

  return MachineItem(
    id: _requiredString(map, 'id'),
    name:
        _firstPresentString(map, fields: const ['name', 'hostname']) ??
        'Unnamed machine',
    status:
        _firstPresentString(
          map,
          fields: const ['status', 'connectionStatus'],
        ) ??
        'offline',
    statusVersion: _readInt(map['statusVersion']),
    runtimes: runtimes,
    apiKeyPrefix: _firstPresentString(
      map,
      fields: const ['apiKeyPrefix', 'keyPrefix', 'apiKeyPreview'],
    ),
    hostname:
        _firstPresentString(map, fields: const ['hostname']) ??
        _firstPresentString(capabilities, fields: const ['hostname']),
    os:
        _firstPresentString(map, fields: const ['os']) ??
        _firstPresentString(capabilities, fields: const ['os']),
    daemonVersion:
        _firstPresentString(map, fields: const ['daemonVersion']) ??
        _firstPresentString(capabilities, fields: const ['daemonVersion']),
  );
}

String deriveApiKeyPrefix(String apiKey) {
  if (apiKey.isEmpty) {
    return '';
  }
  return apiKey.substring(0, math.min(apiKey.length, 20));
}

Map<String, dynamic>? _readMap(Object? payload) {
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }
  return null;
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = _readOptionalString(map[key]);
  if (value != null) {
    return value;
  }
  throw ArgumentError('Missing required machine field: $key');
}

String? _firstPresentString(
  Map<String, dynamic>? payload, {
  required List<String> fields,
}) {
  if (payload == null) {
    return null;
  }
  for (final field in fields) {
    final value = _readOptionalString(payload[field]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

String? _readOptionalString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

int? _readInt(Object? value) {
  return switch (value) {
    final int raw => raw,
    final num raw => raw.toInt(),
    _ => null,
  };
}

List<String>? _readStringList(Object? value) {
  if (value is! List) {
    return null;
  }

  return value
      .map(_readOptionalString)
      .whereType<String>()
      .toList(growable: false);
}
