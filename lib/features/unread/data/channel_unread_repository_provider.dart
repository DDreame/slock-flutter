import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/unread/data/channel_unread_repository.dart';

const _serverHeaderName = 'X-Server-Id';
const _unreadPath = '/channels/unread';
const _channelsPath = '/channels';
const _readSuffix = '/read';
const _inboxReadAllPath = '/channels/inbox/read-all';

final channelUnreadRepositoryProvider =
    Provider<ChannelUnreadRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiChannelUnreadRepository(appDioClient: appDioClient);
});

class _ApiChannelUnreadRepository implements ChannelUnreadRepository {
  _ApiChannelUnreadRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<Map<String, int>> fetchUnreadCounts(
    ServerScopeId serverId,
  ) async {
    try {
      final response = await _appDioClient.get<Object?>(
        _unreadPath,
        options: _serverScopedOptions(serverId),
      );
      return _parseUnreadResponse(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to fetch unread counts.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> markChannelRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_channelsPath/$channelId$_readSuffix',
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to mark channel read.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> markAllInboxRead(ServerScopeId serverId) async {
    try {
      await _appDioClient.post<Object?>(
        _inboxReadAllPath,
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to mark all inbox read.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  Options _serverScopedOptions(ServerScopeId serverId) {
    return Options(headers: {_serverHeaderName: serverId.value});
  }

  /// Parses the `GET /channels/unread` response.
  ///
  /// Expects either:
  /// - A list of `{channelId: string, unreadCount: int}` objects
  /// - Or a map of `{channelId: unreadCount}` entries
  Map<String, int> _parseUnreadResponse(Object? data) {
    if (data is List) {
      final result = <String, int>{};
      for (final item in data) {
        if (item is! Map) continue;
        final id = item['channelId'] ?? item['id'];
        if (id is! String || id.isEmpty) continue;
        final raw = item['unreadCount'] ?? item['count'];
        final count = raw is int ? raw : (raw is num ? raw.toInt() : null);
        if (count != null && count > 0) {
          result[id] = count;
        }
      }
      return result;
    }
    if (data is Map) {
      final result = <String, int>{};
      for (final entry in data.entries) {
        final id = entry.key;
        if (id is! String || id.isEmpty) continue;
        final raw = entry.value;
        final count = raw is int ? raw : (raw is num ? raw.toInt() : null);
        if (count != null && count > 0) {
          result[id] = count;
        }
      }
      return result;
    }
    return const {};
  }
}
