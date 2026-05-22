import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/profile/data/profile_edit_repository.dart';

void main() {
  test('updateCurrentUser PATCHes existing web profile endpoint', () async {
    final appDioClient = _FakeAppDioClient(
      response: {
        'id': 'user-1',
        'name': 'Alice Updated',
        'bio': 'Updated bio',
        'avatarUrl': 'https://example.com/avatar.png',
      },
    );
    final container = ProviderContainer(
      overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
    );
    addTearDown(container.dispose);

    final profile =
        await container.read(profileEditRepositoryProvider).updateCurrentUser(
              displayName: 'Alice Updated',
              bio: 'Updated bio',
            );

    expect(profile.displayName, 'Alice Updated');
    expect(profile.description, 'Updated bio');
    expect(profile.avatarUrl, 'https://example.com/avatar.png');
    expect(appDioClient.requests.single.method, 'PATCH');
    expect(appDioClient.requests.single.path, '/auth/me');
    expect(appDioClient.requests.single.data, {
      'name': 'Alice Updated',
      'bio': 'Updated bio',
    });
  });
}

class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({required this.response}) : super(Dio());

  final Object? response;
  final requests = <_CapturedRequest>[];

  @override
  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    requests.add(_CapturedRequest(method: method, path: path, data: data));
    return Response<T>(
      requestOptions: RequestOptions(path: path, method: method),
      data: response as T,
    );
  }
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.data,
  });

  final String method;
  final String path;
  final Object? data;
}
