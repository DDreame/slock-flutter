import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_management_repository.dart';

const _serverHeaderName = 'X-Server-Id';
const _channelsPath = '/channels';

final channelManagementRepositoryProvider =
    Provider<ChannelManagementRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiChannelManagementRepository(appDioClient: appDioClient);
});

class _ApiChannelManagementRepository implements ChannelManagementRepository {
  const _ApiChannelManagementRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<String> createChannel(
    ServerScopeId serverId, {
    required String name,
    String? description,
    bool? isPrivate,
  }) async {
    try {
      final data = <String, Object>{
        'name': name,
        'type': 'text',
      };
      if (description != null && description.isNotEmpty) {
        data['description'] = description;
      }
      if (isPrivate != null) {
        data['isPrivate'] = isPrivate;
      }
      final response = await _appDioClient.post<Object?>(
        _channelsPath,
        data: data,
        options: _serverScopedOptions(serverId),
      );
      final channelId = _readOptionalChannelId(response.data);
      if (channelId == null) {
        throw const UnknownFailure(
          message: 'Server did not return a channel ID.',
          causeType: 'missing_channel_id',
        );
      }
      return channelId;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to create channel.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> updateChannel(
    ServerScopeId serverId, {
    required String channelId,
    required String name,
  }) async {
    try {
      await _appDioClient.request<Object?>(
        '$_channelsPath/$channelId',
        method: 'PATCH',
        data: {'name': name},
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to update channel.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> deleteChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    try {
      await _appDioClient.delete<Object?>(
        '$_channelsPath/$channelId',
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to delete channel.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> leaveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_channelsPath/$channelId/leave',
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to leave channel.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> stopAllAgents(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_channelsPath/$channelId/stop-all-agents',
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to stop all agents.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> resumeAllAgents(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_channelsPath/$channelId/resume-all-agents',
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to resume all agents.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  Options _serverScopedOptions(ServerScopeId serverId) {
    return Options(headers: {_serverHeaderName: serverId.value});
  }
}

String? _readOptionalChannelId(Object? payload) {
  if (payload is Map<String, dynamic>) {
    return _readStringField(payload['id']);
  }
  if (payload is Map) {
    return _readStringField(payload['id']);
  }
  return null;
}

String? _readStringField(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}
