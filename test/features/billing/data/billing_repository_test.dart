import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/data/billing_repository_provider.dart';

void main() {
  test(
    'billingRepositoryProvider gets /billing/subscription summary',
    () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/billing/subscription'): {
            'subscription': {
              'planName': 'Pro',
              'status': 'active',
              'amountCents': 1250,
              'currency': 'usd',
              'currentPeriodEnd': '2026-05-01',
              'portalUrl': 'https://billing.example.com/manage',
            },
          },
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(billingRepositoryProvider);
      final summary = await repository.loadSubscription();

      expect(
        summary,
        const BillingSummary(
          planName: 'Pro',
          status: 'active',
          amountLabel: 'USD 12.50',
          renewalLabel: '2026-05-01',
          manageUrl: 'https://billing.example.com/manage',
        ),
      );
      expect(appDioClient.requests, hasLength(1));
      expect(appDioClient.requests.single.method, 'GET');
      expect(appDioClient.requests.single.path, '/billing/subscription');
    },
  );
}

class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({Map<(String, String), Object?> responses = const {}})
    : _responses = responses,
      super(Dio());

  final Map<(String, String), Object?> _responses;
  final List<_CapturedRequest> requests = [];

  @override
  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    requests.add(_CapturedRequest(method: method, path: path));

    final key = (method, path);
    if (!_responses.containsKey(key)) {
      throw StateError('Missing fake response for $key');
    }

    return Response<T>(
      requestOptions: RequestOptions(path: path, method: method),
      data: _responses[key] as T,
    );
  }
}

class _CapturedRequest {
  const _CapturedRequest({required this.method, required this.path});

  final String method;
  final String path;
}
