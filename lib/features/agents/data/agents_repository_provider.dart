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

class _ApiAgentsRepository
    implements AgentsRepository, AgentsMutationRepository {
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
}

/// Loads the machine list for the active server,
/// used by the Agents Tab to resolve machine names
/// for grouping.  Returns an empty list when the
/// server ID is not set or the request fails.
typedef AgentsMachinesLoader = Future<List<MachineItem>> Function();

final agentsMachinesLoaderProvider = Provider<AgentsMachinesLoader>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final serverId = ref.watch(activeServerScopeIdProvider);
  return () => _loadMachinesForAgents(
        appDioClient: appDioClient,
        serverId: serverId,
      );
});

Future<List<MachineItem>> _loadMachinesForAgents({
  required AppDioClient appDioClient,
  required ServerScopeId? serverId,
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
  } catch (_) {
    return const [];
  }
}
