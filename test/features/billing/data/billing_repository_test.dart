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

  test(
    'billingRepositoryProvider gets /servers/:serverId/usage summary',
    () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/servers/server-1/usage'): {
            'usage': {
              'plan': {'code': 'free'},
              'usage': {'agentsUsed': 1, 'machinesUsed': 2, 'channelsUsed': 3},
              'limits': {
                'maxAgents': 1,
                'maxMachines': 4,
                'maxChannels': 10,
                'messageHistoryDays': 30,
              },
              'planDowngradedAt': '2026-04-20',
            },
          },
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(billingRepositoryProvider);
      final usage = await repository.loadServerUsage(
        const ServerScopeId('server-1'),
      );

      expect(
        usage,
        const BillingUsageSummary(
          planCode: 'free',
          planName: 'Hobby',
          planDowngradedAt: '2026-04-20',
          messageHistoryDays: 30,
          resources: [
            BillingUsageResource(label: 'Agents', used: 1, limit: 1),
            BillingUsageResource(label: 'Machines', used: 2, limit: 4),
            BillingUsageResource(label: 'Channels', used: 3, limit: 10),
          ],
        ),
      );
      expect(appDioClient.requests, hasLength(1));
      expect(appDioClient.requests.single.method, 'GET');
      expect(appDioClient.requests.single.path, '/servers/server-1/usage');
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
