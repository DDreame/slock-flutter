import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/search/data/search_repository_provider.dart';

import '../../../support/fakes/fake_app_dio_client.dart';

void main() {
  test('search repository forwards CancelToken to AppDioClient', () async {
    final fakeClient = FakeAppDioClient(
      responses: const {
        ('GET', '/messages/search'): {
          'results': <Object?>[],
          'hasMore': false,
        },
      },
    );
    final container = ProviderContainer(
      overrides: [appDioClientProvider.overrideWithValue(fakeClient)],
    );
    addTearDown(container.dispose);

    final cancelToken = CancelToken();
    final repo = container.read(searchRepositoryProvider);

    await repo.searchMessages(
      const ServerScopeId('srv-1'),
      'query',
      cancelToken: cancelToken,
    );

    expect(fakeClient.requests.single.cancelToken, same(cancelToken));
  });
}
