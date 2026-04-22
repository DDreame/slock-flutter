import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/data/billing_repository_provider.dart';
import 'package:slock_app/features/billing/presentation/page/billing_page.dart';

void main() {
  testWidgets('billing page shows subscription summary', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        repository: const _FakeBillingRepository(
          summary: BillingSummary(
            planName: 'Pro',
            status: 'active',
            amountLabel: 'USD 12.50',
            renewalLabel: '2026-05-01',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('billing-success')), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('active'), findsOneWidget);
    expect(find.text('USD 12.50'), findsOneWidget);
    expect(find.text('2026-05-01'), findsOneWidget);
  });

  testWidgets('billing page shows retry state on failure', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        repository: const _FakeBillingRepository(
          failure: UnknownFailure(
            message: 'Billing failed',
            causeType: 'test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('billing-error')), findsOneWidget);
    expect(find.text('Billing failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

Widget _buildApp({required BillingRepository repository}) {
  return ProviderScope(
    overrides: [billingRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: BillingPage()),
  );
}

class _FakeBillingRepository implements BillingRepository {
  const _FakeBillingRepository({this.summary, this.failure});

  final BillingSummary? summary;
  final AppFailure? failure;

  @override
  Future<BillingSummary> loadSubscription() async {
    if (failure != null) {
      throw failure!;
    }
    return summary ?? const BillingSummary();
  }
}
