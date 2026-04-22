import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

const _membersPath = '/members';
const _directMessagePath = '/channels/dm';
const _serverHeaderName = 'X-Server-Id';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiMemberRepository(appDioClient: appDioClient);
});

class _ApiMemberRepository implements MemberRepository {
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
