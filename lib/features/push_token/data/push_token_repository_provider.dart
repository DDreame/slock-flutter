import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/core/network/dio_client.dart';
import 'package:slock_app/core/network/providers.dart';
import 'package:slock_app/features/push_token/data/push_token_repository.dart';

final pushTokenRepositoryProvider = Provider<PushTokenRepository>((ref) {
  return _ApiPushTokenRepository(ref.watch(appDioClientProvider));
});

class _ApiPushTokenRepository implements PushTokenRepository {
  _ApiPushTokenRepository(this._client);

  final AppDioClient _client;

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    try {
      await _client.post(
        '/push/subscribe',
        data: {'token': token, 'platform': platform},
      );
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw UnknownFailure(message: e.toString());
    }
  }

  @override
  Future<void> deregisterToken({
    required String token,
    String? authToken,
  }) async {
    try {
      await _client.delete(
        '/push/subscribe',
        data: {'token': token},
        options: authToken != null
            ? Options(headers: {'Authorization': 'Bearer $authToken'})
            : null,
      );
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw UnknownFailure(message: e.toString());
    }
  }
}
