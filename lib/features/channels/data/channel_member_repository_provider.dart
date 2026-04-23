import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';

const _serverHeaderName = 'X-Server-Id';
const _channelsPath = '/channels';

final channelMemberRepositoryProvider =
    Provider<ChannelMemberRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiChannelMemberRepository(appDioClient: appDioClient);
});

class _ApiChannelMemberRepository implements ChannelMemberRepository {
  const _ApiChannelMemberRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  Options _serverOptions(ServerScopeId serverId) =>
      Options(headers: {_serverHeaderName: serverId.value});

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_channelsPath/$channelId/members',
        options: _serverOptions(serverId),
      );
      return _parseMemberList(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load channel members.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_channelsPath/$channelId/members',
        data: {'userId': userId},
        options: _serverOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to add member.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> addAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_channelsPath/$channelId/members',
        data: {'agentId': agentId},
        options: _serverOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to add agent.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> removeHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {
    try {
      await _appDioClient.delete<Object?>(
        '$_channelsPath/$channelId/members/user/$userId',
        options: _serverOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to remove member.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> removeAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {
    try {
      await _appDioClient.delete<Object?>(
        '$_channelsPath/$channelId/members/agent/$agentId',
        options: _serverOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to remove agent.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  List<ChannelMember> _parseMemberList(Object? payload) {
    if (payload is List) {
      return payload.whereType<Map>().map(_parseMemberMap).toList();
    }
    final map = _requireMap(payload);
    final humans = map['humans'];
    final agents = map['agents'];
    if (humans is List || agents is List) {
      return [
        if (humans is List) ...humans.whereType<Map>().map(_parseMemberMap),
        if (agents is List) ...agents.whereType<Map>().map(_parseMemberMap),
      ];
    }
    final members = map['members'];
    if (members is List) {
      return members.whereType<Map>().map(_parseMemberMap).toList();
    }
    return [];
  }

  ChannelMember _parseMemberMap(Map<dynamic, dynamic> raw) {
    final map =
        raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw);
    return ChannelMember(
      id: _requireString(map, 'id'),
      channelId: _optionalString(map['channelId']) ?? '',
      userId: _optionalString(map['userId']),
      agentId: _optionalString(map['agentId']),
      userName: _readNestedName(map['user']),
      agentName: _readNestedName(map['agent']),
      avatarUrl:
          _readNestedAvatar(map['user']) ?? _readNestedAvatar(map['agent']),
    );
  }

  String? _readNestedName(Object? obj) {
    final map = _optionalMap(obj);
    if (map == null) return null;
    return _optionalString(map['displayName']) ?? _optionalString(map['name']);
  }

  String? _readNestedAvatar(Object? obj) {
    final map = _optionalMap(obj);
    if (map == null) return null;
    return _optionalString(map['avatarUrl']);
  }

  Map<String, dynamic> _requireMap(Object? payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    throw const UnknownFailure(
      message: 'Invalid response format.',
      causeType: 'ParseError',
    );
  }

  Map<String, dynamic>? _optionalMap(Object? payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
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
