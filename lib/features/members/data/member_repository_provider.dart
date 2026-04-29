import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

const _membersPath = '/members';
const _serversPath = '/servers';
const _directMessagePath = '/channels/dm';
const _serverHeaderName = 'X-Server-Id';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiMemberRepository(appDioClient: appDioClient);
});

class _ApiMemberRepository
    implements MemberRepository, MemberInviteMutationRepository {
  const _ApiMemberRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    try {
      final response = await _appDioClient.get<Object?>(
        _membersPath,
        options: _serverScopedOptions(serverId),
      );
      final entries = _readMemberEntries(response.data);
      return entries
          .map(
            (entry) => parseMemberProfilePayload(
              entry,
              fallbackUserId: _readMemberId(entry) ?? 'unknown',
            ),
          )
          .toList(growable: false);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load members.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<String> createInvite(ServerScopeId serverId) async {
    try {
      final response = await _appDioClient.post<Object?>(
        _serverInvitesPath(serverId),
        options: _serverScopedOptions(serverId),
      );
      final inviteCode = _readInviteCode(response.data);
      if (inviteCode == null) {
        throw const SerializationFailure(
          message:
              'Malformed invite payload: missing invite link, code, or token.',
        );
      }
      return inviteCode;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to create invite.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> inviteByEmail(
    ServerScopeId serverId, {
    required String email,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        _serverInvitesPath(serverId),
        data: {'email': email},
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to send invite email.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) async {
    try {
      await _appDioClient.request<Object?>(
        _serverMemberPath(serverId, userId: userId),
        method: 'PATCH',
        data: {'role': role},
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to update member role.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    try {
      await _appDioClient.delete<Object?>(
        _serverMemberPath(serverId, userId: userId),
        options: _serverScopedOptions(serverId),
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
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    try {
      final response = await _appDioClient.post<Object?>(
        _directMessagePath,
        data: {'userId': userId},
        options: _serverScopedOptions(serverId),
      );
      final channelId = _readOptionalChannelId(response.data);
      if (channelId == null) {
        throw const SerializationFailure(
          message:
              'Malformed direct-message payload: missing string field "id".',
        );
      }
      return channelId;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to open direct message.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  Options _serverScopedOptions(ServerScopeId serverId) {
    return Options(headers: {_serverHeaderName: serverId.value});
  }
}

String _serverInvitesPath(ServerScopeId serverId) {
  return '$_serversPath/${serverId.routeParam}/invites';
}

String _serverMemberPath(ServerScopeId serverId, {required String userId}) {
  return '$_serversPath/${serverId.routeParam}/members/$userId';
}

List<Object?> _readMemberEntries(Object? payload) {
  if (payload is List) {
    return List<Object?>.from(payload);
  }
  final map = readProfilePayloadMap(payload);
  if (map != null && map['members'] is List) {
    return List<Object?>.from(map['members'] as List);
  }
  throw const SerializationFailure(
    message: 'Malformed members payload: expected a list.',
  );
}

String? _readMemberId(Object? payload) {
  final map = readProfilePayloadMap(payload);
  if (map == null) {
    return null;
  }
  for (final field in const ['id', 'userId', 'memberId']) {
    final value = map[field];
    if (value is String && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String? _readOptionalChannelId(Object? payload) {
  final map = readProfilePayloadMap(payload);
  if (map == null) {
    return null;
  }
  final direct = map['id'];
  if (direct is String && direct.isNotEmpty) {
    return direct;
  }
  final nested = map['channel'];
  if (nested is Map) {
    final id = nested['id'];
    if (id is String && id.isNotEmpty) {
      return id;
    }
  }
  return null;
}

String? _readInviteCode(Object? payload) {
  final root = _readOptionalMap(payload);
  if (root == null) {
    return null;
  }

  final nested = _readOptionalMap(root['invite']);
  final invite = nested ?? root;
  for (final field in const ['url', 'inviteUrl', 'link', 'code', 'token']) {
    final value = invite[field];
    if (value is String && value.isNotEmpty) {
      return value;
    }
  }

  return null;
}

Map<String, dynamic>? _readOptionalMap(Object? payload) {
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }
  return null;
}
