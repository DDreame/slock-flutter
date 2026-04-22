import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/application/billing_state.dart';
import 'package:slock_app/features/billing/data/billing_repository_provider.dart';

final billingStoreProvider =
    AutoDisposeNotifierProvider<BillingStore, BillingState>(BillingStore.new);

class BillingStore extends AutoDisposeNotifier<BillingState> {
  @override
  BillingState build() => const BillingState();

  Future<void> ensureLoaded() async {
    if (state.status == BillingStatus.loading ||
        state.status == BillingStatus.success) {
      return;
    }
    await load();
  }

  Future<void> load() async {
    state = state.copyWith(status: BillingStatus.loading, clearFailure: true);

    try {
      final summary =
          await ref.read(billingRepositoryProvider).loadSubscription();
      state = state.copyWith(
        status: BillingStatus.success,
        summary: summary,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(status: BillingStatus.failure, failure: failure);
    }
  }
}
