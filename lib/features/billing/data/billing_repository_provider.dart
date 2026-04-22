import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';

const _billingSubscriptionPath = '/billing/subscription';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiBillingRepository(appDioClient: appDioClient);
});

class _ApiBillingRepository implements BillingRepository {
  const _ApiBillingRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<BillingSummary> loadSubscription() async {
    try {
      final response = await _appDioClient.get<Object?>(
        _billingSubscriptionPath,
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
}
