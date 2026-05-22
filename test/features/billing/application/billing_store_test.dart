import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/application/billing_state.dart';
import 'package:slock_app/features/billing/application/billing_store.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/data/billing_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';

void main() {
  const server1 = ServerScopeId('server-1');
  const server2 = ServerScopeId('server-2');

  test('ensureLoaded populates billing summary', () async {
    final repository = _FakeBillingRepository(
      summary: const BillingSummary(planName: 'Pro', status: 'active'),
    );
    final container = ProviderContainer(
      overrides: [billingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      billingStoreProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);

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
            server1,
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        billingStoreProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);

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
          server1,
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      billingStoreProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);

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

  test('load discards results when active server changes during request',
      () async {
    final activeServer = StateProvider<ServerScopeId?>((ref) => server1);
    final summaryCompleter = Completer<BillingSummary>();
    final usageCompleter = Completer<BillingUsageSummary>();
    final repository = _FakeBillingRepository(
      summaryCompleter: summaryCompleter,
      usageCompleter: usageCompleter,
    );
    final container = ProviderContainer(
      overrides: [
        billingRepositoryProvider.overrideWithValue(repository),
        activeServerScopeIdProvider.overrideWith(
          (ref) => ref.watch(activeServer),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      billingStoreProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);

    final loadFuture = container.read(billingStoreProvider.notifier).load();
    await Future<void>.delayed(Duration.zero);

    container.read(activeServer.notifier).state = server2;
    summaryCompleter.complete(
      const BillingSummary(planName: 'Old server plan', status: 'active'),
    );
    usageCompleter.complete(
      const BillingUsageSummary(planName: 'Old server usage'),
    );

    await loadFuture;

    final state = container.read(billingStoreProvider);
    expect(state.status, isNot(BillingStatus.success));
    expect(state.summary, isNull);
    expect(state.usage, isNull);
    expect(state.hasActiveServerScope, isTrue);
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
          server1,
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      billingStoreProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);

    await container.read(billingStoreProvider.notifier).load();

    final state = container.read(billingStoreProvider);
    expect(state.status, BillingStatus.failure);
    expect(state.failure?.message, 'Billing failed');
  });

  test('load wraps unexpected summary errors and exits loading', () async {
    final container = ProviderContainer(
      overrides: [
        billingRepositoryProvider.overrideWithValue(
          _FakeBillingRepository(
            summaryError: const FormatException('bad billing payload'),
          ),
        ),
        activeServerScopeIdProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      billingStoreProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);

    await container.read(billingStoreProvider.notifier).load();

    final state = container.read(billingStoreProvider);
    expect(state.status, BillingStatus.failure);
    expect(state.failure, isA<UnknownFailure>());
    expect(state.failure?.causeType, 'FormatException');
    expect(state.hasActiveServerScope, isFalse);
  });

  test('load recovers when unexpected usage error reporting throws', () async {
    final container = ProviderContainer(
      overrides: [
        billingRepositoryProvider.overrideWithValue(
          _FakeBillingRepository(
            usageError: const FormatException('bad usage payload'),
          ),
        ),
        activeServerScopeIdProvider.overrideWithValue(server1),
        crashReporterProvider.overrideWithValue(_ThrowingCrashReporter()),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      billingStoreProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);

    await container.read(billingStoreProvider.notifier).load();

    final state = container.read(billingStoreProvider);
    expect(state.status, BillingStatus.success);
    expect(state.summary, const BillingSummary());
    expect(state.usage, isNull);
    expect(state.hasActiveServerScope, isTrue);
  });
}

class _FakeBillingRepository implements BillingRepository {
  _FakeBillingRepository({
    this.summary,
    this.usage,
    this.summaryFailure,
    this.usageFailure,
    this.summaryError,
    this.usageError,
    this.summaryCompleter,
    this.usageCompleter,
  });

  final BillingSummary? summary;
  final BillingUsageSummary? usage;
  final AppFailure? summaryFailure;
  final AppFailure? usageFailure;
  final Object? summaryError;
  final Object? usageError;
  final Completer<BillingSummary>? summaryCompleter;
  final Completer<BillingUsageSummary>? usageCompleter;
  var loadSubscriptionCount = 0;
  var loadServerUsageCount = 0;

  @override
  Future<BillingSummary> loadSubscription() async {
    loadSubscriptionCount += 1;
    if (summaryFailure != null) {
      throw summaryFailure!;
    }
    final error = summaryError;
    if (error != null) throw error;
    if (summaryCompleter != null) {
      return summaryCompleter!.future;
    }
    return summary ?? const BillingSummary();
  }

  @override
  Future<BillingUsageSummary> loadServerUsage(ServerScopeId serverId) async {
    loadServerUsageCount += 1;
    if (usageFailure != null) {
      throw usageFailure!;
    }
    final error = usageError;
    if (error != null) throw error;
    if (usageCompleter != null) {
      return usageCompleter!.future;
    }
    return usage ?? const BillingUsageSummary();
  }
}

class _ThrowingCrashReporter implements CrashReporter {
  @override
  Future<void> init() async {}

  @override
  void captureException(
    Object error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    throw StateError('crash reporter failed');
  }

  @override
  void captureFlutterError(FlutterErrorDetails details) {}

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {}

  @override
  void setUser(String? userId, {String? displayName}) {}
}
