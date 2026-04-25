import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/application/billing_realtime_binding.dart';
import 'package:slock_app/features/billing/application/billing_state.dart';
import 'package:slock_app/features/billing/application/billing_store.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/data/billing_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';

void main() {
  late _FakeBillingRepository fakeRepository;
  late RealtimeReductionIngress ingress;
  late ProviderContainer container;
  late ProviderSubscription<BillingState> stateSub;
  late ProviderSubscription<void> bindingSub;

  setUp(() {
    fakeRepository = _FakeBillingRepository();
    ingress = RealtimeReductionIngress();
    container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
        billingRepositoryProvider.overrideWithValue(fakeRepository),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
      ],
    );
    stateSub = container.listen(billingStoreProvider, (_, __) {});
    bindingSub = container.listen(billingRealtimeBindingProvider, (_, __) {});
  });

  tearDown(() async {
    bindingSub.close();
    stateSub.close();
    container.dispose();
    await ingress.dispose();
  });

  test(
    'server:plan-updated reloads billing store for the active server',
    () async {
      fakeRepository.summary = const BillingSummary(
        planName: 'Starter',
        status: 'active',
      );
      fakeRepository.usage = const BillingUsageSummary(
        planCode: 'free',
        planName: 'Hobby',
      );
      await container.read(billingStoreProvider.notifier).load();

      fakeRepository.summary = const BillingSummary(
        planName: 'Business',
        status: 'active',
      );
      fakeRepository.usage = const BillingUsageSummary(
        planCode: 'max',
        planName: 'Business',
      );

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'server:plan-updated',
          scopeKey: 'server:server-1',
          seq: 1,
          receivedAt: DateTime.now(),
        ),
      );

      await _drainAsyncWork();

      expect(fakeRepository.loadSubscriptionCount, 2);
      expect(fakeRepository.loadServerUsageCount, 2);
      final state = container.read(billingStoreProvider);
      expect(state.summary?.planName, 'Business');
      expect(state.usage?.planName, 'Business');
    },
  );

  test(
    'foreign server scopes do not reload the mounted billing store',
    () async {
      fakeRepository.summary = const BillingSummary(
        planName: 'Starter',
        status: 'active',
      );
      fakeRepository.usage = const BillingUsageSummary(
        planCode: 'free',
        planName: 'Hobby',
      );
      await container.read(billingStoreProvider.notifier).load();

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'server:plan-updated',
          scopeKey: 'server:server-9',
          seq: 1,
          receivedAt: DateTime.now(),
        ),
      );

      await _drainAsyncWork();

      expect(fakeRepository.loadSubscriptionCount, 1);
      expect(fakeRepository.loadServerUsageCount, 1);
      expect(container.read(billingStoreProvider).summary?.planName, 'Starter');
    },
  );

  test('unrelated event types do not reload the billing store', () async {
    fakeRepository.summary = const BillingSummary(
      planName: 'Starter',
      status: 'active',
    );
    fakeRepository.usage = const BillingUsageSummary(
      planCode: 'free',
      planName: 'Hobby',
    );
    await container.read(billingStoreProvider.notifier).load();

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'task:updated',
        scopeKey: 'server:server-1',
        seq: 1,
        receivedAt: DateTime.now(),
      ),
    );

    await _drainAsyncWork();

    expect(fakeRepository.loadSubscriptionCount, 1);
    expect(fakeRepository.loadServerUsageCount, 1);
  });

  test('no active server scope ignores server:plan-updated events', () async {
    final ingress = RealtimeReductionIngress();
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(null),
        billingRepositoryProvider.overrideWithValue(fakeRepository),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(ingress.dispose);

    final stateSub = container.listen(billingStoreProvider, (_, __) {});
    final bindingSub = container.listen(
      billingRealtimeBindingProvider,
      (_, __) {},
    );
    addTearDown(stateSub.close);
    addTearDown(bindingSub.close);

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'server:plan-updated',
        scopeKey: 'server:server-1',
        seq: 1,
        receivedAt: DateTime.now(),
      ),
    );

    await _drainAsyncWork();

    expect(fakeRepository.loadSubscriptionCount, 0);
    expect(fakeRepository.loadServerUsageCount, 0);
  });
}

Future<void> _drainAsyncWork() async {
  for (var i = 0; i < 3; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeBillingRepository implements BillingRepository {
  BillingSummary summary = const BillingSummary();
  BillingUsageSummary usage = const BillingUsageSummary();
  var loadSubscriptionCount = 0;
  var loadServerUsageCount = 0;

  @override
  Future<BillingSummary> loadSubscription() async {
    loadSubscriptionCount += 1;
    return summary;
  }

  @override
  Future<BillingUsageSummary> loadServerUsage(ServerScopeId serverId) async {
    loadServerUsageCount += 1;
    return usage;
  }
}
