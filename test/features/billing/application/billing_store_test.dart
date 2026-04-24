import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/application/billing_state.dart';
import 'package:slock_app/features/billing/application/billing_store.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/data/billing_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';

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

    expect(repository.loadSubscriptionCount, 1);
    expect(repository.loadServerUsageCount, 0);
    expect(
      container.read(billingStoreProvider),
      const BillingState(
        status: BillingStatus.success,
        summary: BillingSummary(planName: 'Pro', status: 'active'),
        hasActiveServerScope: false,
      ),
    );
  });

  test(
    'ensureLoaded loads billing summary and server usage for active server',
    () async {
      final repository = _FakeBillingRepository(
        summary: const BillingSummary(planName: 'Pro', status: 'active'),
        usage: const BillingUsageSummary(
          planCode: 'free',
          planName: 'Hobby',
          messageHistoryDays: 30,
          resources: [
            BillingUsageResource(label: 'Agents', used: 1, limit: 1),
            BillingUsageResource(label: 'Machines', used: 2, limit: 4),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          billingRepositoryProvider.overrideWithValue(repository),
          activeServerScopeIdProvider.overrideWithValue(
            const ServerScopeId('server-1'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(billingStoreProvider.notifier).ensureLoaded();

      expect(repository.loadSubscriptionCount, 1);
      expect(repository.loadServerUsageCount, 1);
      expect(
        container.read(billingStoreProvider),
        const BillingState(
          status: BillingStatus.success,
          summary: BillingSummary(planName: 'Pro', status: 'active'),
          usage: BillingUsageSummary(
            planCode: 'free',
            planName: 'Hobby',
            messageHistoryDays: 30,
            resources: [
              BillingUsageResource(label: 'Agents', used: 1, limit: 1),
              BillingUsageResource(label: 'Machines', used: 2, limit: 4),
            ],
          ),
          hasActiveServerScope: true,
        ),
      );
    },
  );

  test('load keeps billing summary when usage request fails', () async {
    final repository = _FakeBillingRepository(
      summary: const BillingSummary(planName: 'Pro', status: 'active'),
      usageFailure: const UnknownFailure(
        message: 'Usage failed',
        causeType: 'test',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        billingRepositoryProvider.overrideWithValue(repository),
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(billingStoreProvider.notifier).load();

    expect(repository.loadSubscriptionCount, 1);
    expect(repository.loadServerUsageCount, 1);
    expect(
      container.read(billingStoreProvider),
      const BillingState(
        status: BillingStatus.success,
        summary: BillingSummary(planName: 'Pro', status: 'active'),
        hasActiveServerScope: true,
      ),
    );
  });

  test('load exposes failure state when summary and usage both fail', () async {
    final container = ProviderContainer(
      overrides: [
        billingRepositoryProvider.overrideWithValue(
          _FakeBillingRepository(
            summaryFailure: const UnknownFailure(
              message: 'Billing failed',
              causeType: 'test',
            ),
            usageFailure: const UnknownFailure(
              message: 'Usage failed',
              causeType: 'test',
            ),
          ),
        ),
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
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
  _FakeBillingRepository({
    this.summary,
    this.usage,
    this.summaryFailure,
    this.usageFailure,
  });

  final BillingSummary? summary;
  final BillingUsageSummary? usage;
  final AppFailure? summaryFailure;
  final AppFailure? usageFailure;
  var loadSubscriptionCount = 0;
  var loadServerUsageCount = 0;

  @override
  Future<BillingSummary> loadSubscription() async {
    loadSubscriptionCount += 1;
    if (summaryFailure != null) {
      throw summaryFailure!;
    }
    return summary ?? const BillingSummary();
  }

  @override
  Future<BillingUsageSummary> loadServerUsage(ServerScopeId serverId) async {
    loadServerUsageCount += 1;
    if (usageFailure != null) {
      throw usageFailure!;
    }
    return usage ?? const BillingUsageSummary();
  }
}
