import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/available_channel.dart';
import 'package:slock_app/features/channels/data/channel_management_repository.dart';

const _serverHeaderName = 'X-Server-Id';
const _channelsPath = '/channels';
const _availableChannelsPath = '/channels/available';

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
  Future<List<AvailableChannel>> loadAvailableChannels(
    ServerScopeId serverId,
  ) async {
    try {
      final response = await _appDioClient.get<Object?>(
        _availableChannelsPath,
        options: _serverScopedOptions(serverId),
      );
      return _parseAvailableChannels(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load available channels.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

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
    String? name,
    String? description,
    bool? isPrivate,
  }) async {
    try {
      final data = <String, Object>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (isPrivate != null) data['isPrivate'] = isPrivate;
      await _appDioClient.request<Object?>(
        '$_channelsPath/$channelId',
        method: 'PATCH',
        data: data,
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
  Future<void> joinChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_channelsPath/$channelId/join',
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to join channel.',
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
  Future<void> archiveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_channelsPath/$channelId/archive',
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to archive channel.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> unarchiveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_channelsPath/$channelId/unarchive',
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to unarchive channel.',
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

List<AvailableChannel> _parseAvailableChannels(Object? payload) {
  final list = switch (payload) {
    List() => payload,
    Map(keys: _) => (payload['channels'] as List?) ?? const [],
    _ => const [],
  };

  return [
    for (final item in list)
      if (item is Map<String, dynamic> &&
          item['id'] is String &&
          item['name'] is String)
        AvailableChannel(
          id: item['id'] as String,
          name: item['name'] as String,
          description: item['description'] as String?,
          memberCount:
              item['memberCount'] is int ? item['memberCount'] as int : null,
        ),
  ];
}
