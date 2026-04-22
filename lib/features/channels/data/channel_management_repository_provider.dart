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
  Future<String?> createChannel(
    ServerScopeId serverId, {
    required String name,
  }) async {
    try {
      final response = await _appDioClient.post<Object?>(
        _channelsPath,
        data: {
          'name': name,
          'type': 'text',
        },
        options: _serverScopedOptions(serverId),
      );
      return _readOptionalChannelId(response.data);
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
