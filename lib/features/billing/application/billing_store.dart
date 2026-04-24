import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/application/billing_state.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/data/billing_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';

final billingStoreProvider =
    AutoDisposeNotifierProvider<BillingStore, BillingState>(
  BillingStore.new,
  dependencies: [activeServerScopeIdProvider],
);

class BillingStore extends AutoDisposeNotifier<BillingState> {
  @override
  BillingState build() {
    final activeServerScope = ref.watch(activeServerScopeIdProvider);
    return BillingState(hasActiveServerScope: activeServerScope != null);
  }

  Future<void> ensureLoaded() async {
    if (state.status == BillingStatus.loading ||
        state.status == BillingStatus.success) {
      return;
    }
    await load();
  }

  Future<void> load() async {
    final activeServerScope = ref.read(activeServerScopeIdProvider);

    state = state.copyWith(
      status: BillingStatus.loading,
      clearFailure: true,
      clearSummary: true,
      clearUsage: true,
      hasActiveServerScope: activeServerScope != null,
    );

    BillingSummary? summary;
    BillingUsageSummary? usage;
    AppFailure? summaryFailure;
    AppFailure? usageFailure;

    final repository = ref.read(billingRepositoryProvider);
    await Future.wait<void>([
      Future<void>(() async {
        try {
          summary = await repository.loadSubscription();
        } on AppFailure catch (failure) {
          summaryFailure = failure;
        }
      }),
      if (activeServerScope != null)
        Future<void>(() async {
          try {
            usage = await repository.loadServerUsage(activeServerScope);
          } on AppFailure catch (failure) {
            usageFailure = failure;
          }
        }),
    ]);

    if (summary == null && usage == null) {
      state = state.copyWith(
        status: BillingStatus.failure,
        failure: summaryFailure ??
            usageFailure ??
            const UnknownFailure(
              message: 'Could not load billing details.',
              causeType: 'unknown',
            ),
        hasActiveServerScope: activeServerScope != null,
      );
      return;
    }

    state = state.copyWith(
      status: BillingStatus.success,
      summary: summary,
      usage: usage,
      clearFailure: true,
      hasActiveServerScope: activeServerScope != null,
    );
  }
}
