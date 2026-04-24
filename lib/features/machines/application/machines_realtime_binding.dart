import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/application/machines_store.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';

const _machineStatusEvent = 'machine:status';
const _machineCapabilitiesEvent = 'machine:capabilities';
const _daemonStatusEvent = 'daemon:status';

final machinesRealtimeBindingProvider = Provider.autoDispose<void>(
  (ref) {
    final serverId = ref.watch(currentMachinesServerIdProvider);
    final ingress = ref.watch(realtimeReductionIngressProvider);
    final subscription = ingress.acceptedEvents.listen((event) {
      if (!_belongsToCurrentServer(serverId, event)) {
        return;
      }

      switch (event.eventType) {
        case _machineStatusEvent:
          _handleMachineStatus(ref, event);
        case _machineCapabilitiesEvent:
          _handleMachineCapabilities(ref, event);
        case _daemonStatusEvent:
          _handleDaemonStatus(ref, event);
      }
    });

    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
  },
  dependencies: [currentMachinesServerIdProvider],
);

bool _belongsToCurrentServer(
  ServerScopeId serverId,
  RealtimeEventEnvelope event,
) {
  final scopeKey = event.scopeKey;
  final serverScopePrefix = 'server:${serverId.value}';
  return scopeKey == RealtimeEventEnvelope.globalScopeKey ||
      scopeKey == serverScopePrefix ||
      scopeKey.startsWith('$serverScopePrefix/');
}

void _handleMachineStatus(Ref ref, RealtimeEventEnvelope event) {
  final map = _asMap(event.payload);
  if (map == null) {
    return;
  }

  final machineId = _optionalString(map['machineId']);
  final status = _optionalString(map['status']);
  final statusVersion = _optionalInt(map['statusVersion']);
  if (machineId == null || status == null) {
    return;
  }

  try {
    ref
        .read(machinesStoreProvider.notifier)
        .updateMachineStatus(machineId, status, statusVersion: statusVersion);
  } catch (_) {}
}

void _handleDaemonStatus(Ref ref, RealtimeEventEnvelope event) {
  final map = _asMap(event.payload);
  if (map == null) {
    return;
  }

  final machineId = _optionalString(map['daemonId']);
  final status = _optionalString(map['status']);
  final statusVersion = _optionalInt(map['statusVersion']);
  if (machineId == null || status == null) {
    return;
  }

  try {
    ref
        .read(machinesStoreProvider.notifier)
        .updateMachineStatus(machineId, status, statusVersion: statusVersion);
  } catch (_) {}
}

void _handleMachineCapabilities(Ref ref, RealtimeEventEnvelope event) {
  final map = _asMap(event.payload);
  if (map == null) {
    return;
  }

  final machineId = _optionalString(map['machineId']);
  if (machineId == null) {
    return;
  }

  try {
    ref.read(machinesStoreProvider.notifier).updateMachineCapabilities(
          machineId,
          runtimes: _stringList(map['runtimes']),
          hostname: _optionalString(map['hostname']),
          os: _optionalString(map['os']),
          daemonVersion: _optionalString(map['daemonVersion']),
        );
  } catch (_) {}
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String? _optionalString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

int? _optionalInt(Object? value) {
  return switch (value) {
    final int raw => raw,
    final num raw => raw.toInt(),
    _ => null,
  };
}

List<String>? _stringList(Object? value) {
  if (value is! List) {
    return null;
  }
  return value
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
