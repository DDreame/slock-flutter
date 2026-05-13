import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/announcements/data/announcement.dart';

const _serverHeaderName = 'X-Server-Id';
const _announcementsPath = '/announcements';

/// Repository for fetching and dismissing announcements.
abstract class AnnouncementRepository {
  Future<List<Announcement>> getActive(ServerScopeId serverId);
  Future<void> dismiss(ServerScopeId serverId,
      {required String announcementId});
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiAnnouncementRepository(appDioClient: appDioClient);
});

class _ApiAnnouncementRepository implements AnnouncementRepository {
  const _ApiAnnouncementRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<List<Announcement>> getActive(ServerScopeId serverId) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_announcementsPath/active',
        options: Options(headers: {_serverHeaderName: serverId.value}),
      );
      return Announcement.parseList(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load announcements.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> dismiss(
    ServerScopeId serverId, {
    required String announcementId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_announcementsPath/$announcementId/dismiss',
        options: Options(headers: {_serverHeaderName: serverId.value}),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to dismiss announcement.',
        causeType: error.runtimeType.toString(),
      );
    }
  }
}
