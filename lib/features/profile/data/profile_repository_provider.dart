import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

const _serversPath = '/servers';
const _serverHeaderName = 'X-Server-Id';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiProfileRepository(appDioClient: appDioClient);
});

class _ApiProfileRepository implements ProfileRepository {
  const _ApiProfileRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_serversPath/${serverId.routeParam}/members/$userId/profile',
        options: Options(headers: {_serverHeaderName: serverId.value}),
      );
      return parseMemberProfilePayload(
        readProfilePayloadMap(response.data),
        fallbackUserId: userId,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load profile.',
        causeType: error.runtimeType.toString(),
      );
    }
  }
}
