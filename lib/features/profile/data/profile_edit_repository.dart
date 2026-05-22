import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

const _mePath = '/auth/me';

final profileEditRepositoryProvider = Provider<ProfileEditRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return ApiProfileEditRepository(appDioClient: appDioClient);
});

abstract class ProfileEditRepository {
  Future<MemberProfile> updateCurrentUser({
    required String displayName,
    required String bio,
  });
}

class ApiProfileEditRepository implements ProfileEditRepository {
  const ApiProfileEditRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<MemberProfile> updateCurrentUser({
    required String displayName,
    required String bio,
  }) async {
    try {
      final response = await _appDioClient.patch<Object?>(
        _mePath,
        data: {
          'name': displayName,
          'bio': bio,
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      final payload = readProfilePayloadMap(response.data);
      if (payload == null) {
        return MemberProfile(
          id: 'me',
          displayName: displayName,
          description: bio,
          isSelf: true,
        );
      }
      return parseMemberProfilePayload(
        payload,
        fallbackUserId: 'me',
        isSelf: true,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to update profile.',
        causeType: error.runtimeType.toString(),
      );
    }
  }
}
