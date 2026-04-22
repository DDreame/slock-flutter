import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/application/billing_state.dart';
import 'package:slock_app/features/billing/application/billing_store.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/data/billing_repository_provider.dart';

void main() {
  test('ensureLoaded populates billing summary', () async {
    final repository = _FakeBillingRepository(
      summary: const BillingSummary(planName: 'Pro', status: 'active'),
    );
    final container = ProviderContainer(
      overrides: [billingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(billingStoreProvider.notifier).ensureLoaded();

    expect(repository.loadCount, 1);
    expect(
      container.read(billingStoreProvider),
      const BillingState(
        status: BillingStatus.success,
        summary: BillingSummary(planName: 'Pro', status: 'active'),
      ),
    );
  });

  test('load exposes failure state when repository throws', () async {
    final container = ProviderContainer(
      overrides: [
        billingRepositoryProvider.overrideWithValue(
          _FakeBillingRepository(
            failure: const UnknownFailure(
              message: 'Billing failed',
              causeType: 'test',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(billingStoreProvider.notifier).load();

    final state = container.read(billingStoreProvider);
    expect(state.status, BillingStatus.failure);
    expect(state.failure?.message, 'Billing failed');
  });
}

class _FakeBillingRepository implements BillingRepository {
  _FakeBillingRepository({this.summary, this.failure});

  final BillingSummary? summary;
  final AppFailure? failure;
  var loadCount = 0;

  @override
  Future<BillingSummary> loadSubscription() async {
    loadCount += 1;
    if (failure != null) {
      throw failure!;
    }
    return summary ?? const BillingSummary();
  }
}
