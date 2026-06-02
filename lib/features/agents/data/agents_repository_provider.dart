import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:dio/dio.dart';

const _agentsPath = '/agents';
const _serversPath = '/servers';
const _serverHeaderName = 'X-Server-Id';

final agentsRepositoryProvider = Provider<AgentsRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final activeServerId = ref.watch(activeServerScopeIdProvider);
  return _ApiAgentsRepository(
    appDioClient: appDioClient,
    activeServerId: activeServerId,
  );
});

/// Provider for agent form operations (machines list, runtime models).
///
/// Uses explicit server IDs rather than the active server scope, since form
/// dialogs may operate on a specific server context.
final agentFormRepositoryProvider = Provider<AgentFormRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiAgentsRepository(
    appDioClient: appDioClient,
    activeServerId: null,
  );
});

class _ApiAgentsRepository
    implements AgentsRepository, AgentsMutationRepository, AgentFormRepository {
  const _ApiAgentsRepository({
    required AppDioClient appDioClient,
    required ServerScopeId? activeServerId,
  })  : _appDioClient = appDioClient,
        _activeServerId = activeServerId;

  final AppDioClient _appDioClient;
  final ServerScopeId? _activeServerId;

  Options? get _serverOptions {
    final activeServerId = _activeServerId;
    if (activeServerId == null) return null;
    return Options(headers: {_serverHeaderName: activeServerId.value});
  }

  @override
  Future<List<AgentItem>> listAgents() async {
    try {
      final response = await _appDioClient.get<Object?>(
        _agentsPath,
        options: _serverOptions,
      );
      return _parseAgentList(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load agents.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async {
    try {
      final response = await _appDioClient.post<Object?>(
        _agentsPath,
        data: input.toCreateJson(),
        options: _serverOptions,
      );
      return _parseAgentItem(_requireMap(response.data));
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to create agent.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<AgentItem> updateAgent(
    String agentId,
    AgentMutationInput input,
  ) async {
    try {
      final response = await _appDioClient.request<Object?>(
        '$_agentsPath/$agentId',
        method: 'PATCH',
        data: input.toUpdateJson(),
        options: _serverOptions,
      );
      return _parseAgentItem(_requireMap(response.data));
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to update agent.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> deleteAgent(String agentId) async {
    try {
      await _appDioClient.delete<Object?>(
        '$_agentsPath/$agentId',
        options: _serverOptions,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to delete agent.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> startAgent(String agentId) async {
    try {
      await _appDioClient.post<Object?>(
        '$_agentsPath/$agentId/start',
        options: _serverOptions,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to start agent.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> stopAgent(String agentId) async {
    try {
      await _appDioClient.post<Object?>(
        '$_agentsPath/$agentId/stop',
        options: _serverOptions,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to stop agent.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {
    try {
      await _appDioClient.post<Object?>(
        '$_agentsPath/$agentId/reset',
        data: {'mode': mode},
        options: _serverOptions,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to reset agent.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_agentsPath/$agentId/activity-log',
        queryParameters: {'limit': limit},
        options: _serverOptions,
      );
      return _parseActivityLog(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load activity log.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<MachinesSnapshot> loadFormMachines(String serverId) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '/servers/$serverId/machines',
        options: Options(headers: {_serverHeaderName: serverId}),
      );
      return parseMachinesSnapshot(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load machines.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<RuntimeModelsResult> loadRuntimeModels({
    required String serverId,
    required String machineId,
    required String runtime,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '/servers/$serverId/machines/$machineId/runtime-models/$runtime',
        options: Options(headers: {_serverHeaderName: serverId}),
      );
      return _parseRuntimeModelsResult(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load runtime models.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  List<AgentItem> _parseAgentList(Object? payload) {
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map(
            (a) => _parseAgentItem(
              a is Map<String, dynamic> ? a : Map<String, dynamic>.from(a),
            ),
          )
          .toList();
    }
    return [];
  }

  AgentItem _parseAgentItem(Map<String, dynamic> map) {
    final status = _optionalString(map['status']) ?? 'inactive';
    final rawActivity = _optionalString(map['activity']);
    final activity = _normalizeActivity(rawActivity, status);

    return AgentItem(
      id: _requireString(map, 'id'),
      name: _requireString(map, 'name'),
      displayName: _optionalString(map['displayName']),
      description: _optionalString(map['description']),
      model: _optionalString(map['model']) ?? '',
      runtime: _optionalString(map['runtime']) ?? '',
      reasoningEffort: _optionalString(map['reasoningEffort']),
      machineId: _optionalString(map['machineId']),
      avatarUrl: _optionalString(map['avatarUrl']),
      status: status,
      activity: activity,
      activityDetail: _optionalString(map['activityDetail']),
      envVars: _optionalStringMap(map['envVars']),
    );
  }

  String _normalizeActivity(String? raw, String status) {
    const validActivities = {
      'online',
      'thinking',
      'working',
      'error',
      'offline',
    };
    if (raw != null && validActivities.contains(raw)) return raw;
    return status == 'active' ? 'working' : 'offline';
  }

  List<AgentActivityLogEntry> _parseActivityLog(Object? payload) {
    if (payload is List) {
      return payload.whereType<Map>().map((entry) {
        final map = entry is Map<String, dynamic>
            ? entry
            : Map<String, dynamic>.from(entry);
        final timestamp =
            DateTime.tryParse(_optionalString(map['timestamp']) ?? '') ??
                DateTime.now();
        final entryText = _optionalString(map['entry']) ?? '';
        return AgentActivityLogEntry(timestamp: timestamp, entry: entryText);
      }).toList();
    }
    final map = _requireMap(payload);
    final entries = map['entries'] ?? map['log'];
    if (entries is! List) return [];
    return _parseActivityLog(entries);
  }

  Map<String, dynamic> _requireMap(Object? payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    throw const UnknownFailure(
      message: 'Invalid response format.',
      causeType: 'ParseError',
    );
  }

  String _requireString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
    throw UnknownFailure(
      message: 'Missing required field: $key',
      causeType: 'ParseError',
    );
  }

  String? _optionalString(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  Map<String, String>? _optionalStringMap(Object? value) {
    if (value is! Map || value.isEmpty) return null;
    return Map<String, String>.fromEntries(
      value.entries
          .where((e) => e.key is String && e.value is String)
          .map((e) => MapEntry(e.key as String, e.value as String)),
    );
  }

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
}

/// Loads the machine list for the active server,
/// used by the Agents Tab to resolve machine names
/// for grouping.  Returns an empty list when the
/// server ID is not set or the request fails.
typedef AgentsMachinesLoader = Future<List<MachineItem>> Function();

final agentsMachinesLoaderProvider = Provider<AgentsMachinesLoader>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final serverId = ref.watch(activeServerScopeIdProvider);
  final diagnostics = ref.watch(diagnosticsCollectorProvider);
  return () => _loadMachinesForAgents(
        appDioClient: appDioClient,
        serverId: serverId,
        diagnostics: diagnostics,
      );
});

Future<List<MachineItem>> _loadMachinesForAgents({
  required AppDioClient appDioClient,
  required ServerScopeId? serverId,
  required DiagnosticsCollector diagnostics,
}) async {
  if (serverId == null || serverId.value.isEmpty) {
    return const [];
  }
  try {
    final response = await appDioClient.get<Object?>(
      '$_serversPath/${serverId.routeParam}/machines',
      options: Options(
        headers: {_serverHeaderName: serverId.value},
      ),
    );
    return parseMachinesSnapshot(response.data).items;
  } on Exception catch (e, st) {
    diagnostics.error(
      'AgentsMachinesLoader',
      'Failed to load machines for server ${serverId.value}: $e',
      metadata: {'stackTrace': st.toString()},
    );
    return const [];
  }
}
