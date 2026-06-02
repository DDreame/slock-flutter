import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';

const _serverHeaderName = 'X-Server-Id';

// ---------------------------------------------------------------------------
// Load machines for a given server (agent form context).
// ---------------------------------------------------------------------------

/// Loads the machines list for a given [serverId].
///
/// Used by [AgentFormDialog] to populate the machine selector.
/// Encapsulates the HTTP call so the presentation layer does not import
/// [appDioClientProvider] directly.
final agentFormLoadMachinesUseCaseProvider =
    Provider<Future<MachinesSnapshot> Function(String serverId)>((ref) {
  return (String serverId) async {
    final client = ref.read(appDioClientProvider);
    final response = await client.get<Object?>(
      '/servers/$serverId/machines',
      options: Options(headers: {_serverHeaderName: serverId}),
    );
    return parseMachinesSnapshot(response.data);
  };
});

// ---------------------------------------------------------------------------
// Load runtime models for a machine + runtime pair.
// ---------------------------------------------------------------------------

/// Result from fetching runtime models for a machine.
@immutable
class RuntimeModelsResult {
  const RuntimeModelsResult({this.models = const [], this.defaultModelId});

  final List<RuntimeModelOption> models;
  final String? defaultModelId;
}

/// A single model option returned by the runtime-models API.
@immutable
class RuntimeModelOption {
  const RuntimeModelOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Loads available models for a specific [runtime] on [machineId] within
/// [serverId].
///
/// Returns a structured [RuntimeModelsResult] with parsed model options.
/// Presentation code uses this instead of raw HTTP via [appDioClientProvider].
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
    final client = ref.read(appDioClientProvider);
    final response = await client.get<Object?>(
      '/servers/$serverId/machines/$machineId/runtime-models/$runtime',
      options: Options(headers: {_serverHeaderName: serverId}),
    );
    return _parseRuntimeModelsResult(response.data);
  };
});

RuntimeModelsResult _parseRuntimeModelsResult(Object? payload) {
  final map = switch (payload) {
    final Map<String, dynamic> value => value,
    final Map value => Map<String, dynamic>.from(value),
    _ => const <String, dynamic>{},
  };

  final models = switch (map['models']) {
    final List raw => raw
        .whereType<Object>()
        .map(_parseModelOption)
        .whereType<RuntimeModelOption>()
        .toList(growable: false),
    _ => const <RuntimeModelOption>[],
  };

  final defaultId = switch (map['default']) {
    final String s when s.isNotEmpty => s,
    _ => null,
  };

  return RuntimeModelsResult(models: models, defaultModelId: defaultId);
}

RuntimeModelOption? _parseModelOption(Object? payload) {
  final map = switch (payload) {
    final Map<String, dynamic> value => value,
    final Map value => Map<String, dynamic>.from(value),
    _ => null,
  };
  if (map == null) return null;

  final id = switch (map['id']) {
    final String s when s.isNotEmpty => s,
    _ => null,
  };
  if (id == null) return null;

  final label = switch (map['label']) {
    final String s when s.isNotEmpty => s,
    _ => id,
  };

  return RuntimeModelOption(id: id, label: label);
}
