// =============================================================================
// #781 — BillingStore Disposal Safety
//
// Verifies:
// A. Disposing the store during load() (after Future.wait completes) does NOT
//    throw StateError from ref.read() — the disposed guard bails early.
// B. Non-AppFailure during load → failure status set (not stuck loading).
//
// Load-bearing proof:
//   Reverting the `if (_disposed) return` guard causes test A to fail
//   (StateError from ref.read after disposal).
//   The non-AppFailure test (B) was already handled by the individual
//   Future.wait closures, but verifying it doesn't regress.
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/application/billing_state.dart';
import 'package:slock_app/features/billing/application/billing_store.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/data/billing_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';

void main() {
  group('#781 — BillingStore disposal safety', () {
    test('dispose during load does not throw StateError', () async {
      final completer = Completer<BillingSummary>();
      final repo = _DelayedBillingRepository(subscriptionCompleter: completer);

      final container = ProviderContainer(
        overrides: [
          billingRepositoryProvider.overrideWithValue(repo),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
        ],
      );

      // Keep provider alive long enough to start load.
      final sub = container.listen(billingStoreProvider, (_, __) {});

      final store = container.read(billingStoreProvider.notifier);
      final loadFuture = store.load();

      // Dispose BEFORE the completer resolves — simulates navigation away.
      sub.close();
      container.dispose();

      // Now complete the future — without the _disposed guard this would
      // trigger ref.read() on a disposed container → StateError.
      completer.complete(const BillingSummary(planName: 'Pro'));

      // If this line is reached without throwing, the guard works.
      // The loadFuture should complete without error.
      await loadFuture;
    });

    test('non-AppFailure during load sets failure status', () async {
      final repo = _ThrowingBillingRepository();

      final container = ProviderContainer(
        overrides: [
          billingRepositoryProvider.overrideWithValue(repo),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
        ],
      );
      addTearDown(container.dispose);

      // Keep provider alive.
      container.listen(billingStoreProvider, (_, __) {});

      final store = container.read(billingStoreProvider.notifier);
      await store.load();

      final state = container.read(billingStoreProvider);
      expect(state.status, BillingStatus.failure,
          reason: '#781: non-AppFailure must set failure status');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('non-AppFailure during load does not leave state stuck in loading',
        () async {
      final repo = _ThrowingBillingRepository();

      final container = ProviderContainer(
        overrides: [
          billingRepositoryProvider.overrideWithValue(repo),
          activeServerScopeIdProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      container.listen(billingStoreProvider, (_, __) {});

      final store = container.read(billingStoreProvider.notifier);
      await store.load();

      final state = container.read(billingStoreProvider);
      // Must not be stuck in loading.
      expect(state.status, isNot(BillingStatus.loading),
          reason: '#781: non-AppFailure must not leave state stuck in loading');
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Repository that delays loadSubscription until a completer is resolved.
/// This lets us dispose the store mid-load.
class _DelayedBillingRepository implements BillingRepository {
  _DelayedBillingRepository({required this.subscriptionCompleter});

  final Completer<BillingSummary> subscriptionCompleter;

  @override
  Future<BillingSummary> loadSubscription() => subscriptionCompleter.future;

  @override
  Future<BillingUsageSummary> loadServerUsage(ServerScopeId serverId) async {
    return const BillingUsageSummary();
  }
}

/// Repository that throws a non-AppFailure exception.
class _ThrowingBillingRepository implements BillingRepository {
  @override
  Future<BillingSummary> loadSubscription() async {
    throw StateError('non-AppFailure test');
  }

  @override
  Future<BillingUsageSummary> loadServerUsage(ServerScopeId serverId) async {
    throw StateError('non-AppFailure test');
  }
}
