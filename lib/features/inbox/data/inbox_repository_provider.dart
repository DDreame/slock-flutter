import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';

const _serverHeaderName = 'X-Server-Id';
const _inboxPath = '/channels/inbox';
const _channelsPath = '/channels';
const _readAllSuffix = '/read-all';
const _inboxDonePath = '/channels/inbox/done';
const _inboxReadAllPath = '/channels/inbox/read-all';

final inboxRepositoryProvider = Provider<InboxRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiInboxRepository(appDioClient: appDioClient);
});

class _ApiInboxRepository implements InboxRepository {
  _ApiInboxRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        _inboxPath,
        queryParameters: {
          'filter': filter.queryValue,
          'limit': limit,
          'offset': offset,
        },
        options: _serverScopedOptions(serverId),
      );
      return InboxResponse.fromJson(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to fetch inbox.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_channelsPath/$channelId$_readAllSuffix',
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to mark inbox item read.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        _inboxDonePath,
        data: {'channelId': channelId},
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to mark inbox item done.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {
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
}
