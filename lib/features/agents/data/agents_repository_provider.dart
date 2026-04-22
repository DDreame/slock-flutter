import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';

const _agentsPath = '/agents';

final agentsRepositoryProvider = Provider<AgentsRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiAgentsRepository(appDioClient: appDioClient);
});

class _ApiAgentsRepository implements AgentsRepository {
  const _ApiAgentsRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<List<AgentItem>> listAgents() async {
    try {
      final response = await _appDioClient.get<Object?>(_agentsPath);
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
  Future<AgentItem> startAgent(String agentId) async {
    try {
      final response = await _appDioClient.post<Object?>(
        '$_agentsPath/$agentId/start',
      );
      return _parseSingleAgent(response.data);
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
  Future<AgentItem> stopAgent(String agentId) async {
    try {
      final response = await _appDioClient.post<Object?>(
        '$_agentsPath/$agentId/stop',
      );
      return _parseSingleAgent(response.data);
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
  Future<AgentItem> resetAgent(String agentId, {required String mode}) async {
    try {
      final response = await _appDioClient.post<Object?>(
        '$_agentsPath/$agentId/reset',
        data: {'mode': mode},
      );
      return _parseSingleAgent(response.data);
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
    final map = _requireMap(payload);
    final agents = map['agents'];
    if (agents is! List) return [];
    return agents
        .whereType<Map>()
        .map((a) => _parseAgentItem(
            a is Map<String, dynamic> ? a : Map<String, dynamic>.from(a)))
        .toList();
  }

  AgentItem _parseSingleAgent(Object? payload) {
    final map = _requireMap(payload);
    final agent = map['agent'];
    if (agent is Map<String, dynamic>) return _parseAgentItem(agent);
    if (agent is Map) return _parseAgentItem(Map<String, dynamic>.from(agent));
    throw const UnknownFailure(
      message: 'Invalid agent response.',
      causeType: 'ParseError',
    );
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
        return AgentActivityLogEntry(
          timestamp: timestamp,
          entry: entryText,
        );
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
