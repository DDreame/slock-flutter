import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';

const _billingSubscriptionPath = '/billing/subscription';
const _serversPath = '/servers';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final activeServerId = ref.watch(activeServerScopeIdProvider);
  return _ApiBillingRepository(
    appDioClient: appDioClient,
    activeServerId: activeServerId,
  );
});

class _ApiBillingRepository implements BillingRepository {
  const _ApiBillingRepository({
    required AppDioClient appDioClient,
    required ServerScopeId? activeServerId,
  })  : _appDioClient = appDioClient,
        _activeServerId = activeServerId;

  final AppDioClient _appDioClient;
  final ServerScopeId? _activeServerId;

  Options? get _serverOptions {
    final serverId = _activeServerId;
    if (serverId == null) return null;
    return Options(headers: {'X-Server-Id': serverId.value});
  }

  @override
  Future<BillingSummary> loadSubscription() async {
    try {
      final response = await _appDioClient.get<Object?>(
        _billingSubscriptionPath,
        options: _serverOptions,
      );
      return parseBillingSummary(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load billing subscription.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<BillingUsageSummary> loadServerUsage(ServerScopeId serverId) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_serversPath/${serverId.routeParam}/usage',
        options: Options(headers: {'X-Server-Id': serverId.value}),
      );
      return parseBillingUsageSummary(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load server usage.',
        causeType: error.runtimeType.toString(),
      );
    }
  }
}
