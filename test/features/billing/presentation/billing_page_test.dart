import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/data/billing_repository_provider.dart';
import 'package:slock_app/features/billing/presentation/billing_portal_launcher.dart';
import 'package:slock_app/features/billing/presentation/page/billing_page.dart';

void main() {
  testWidgets('billing page shows subscription summary', (tester) async {
    final launcher = _FakeBillingPortalLauncher();
    await tester.pumpWidget(
      _buildApp(
        repository: const _FakeBillingRepository(
          summary: BillingSummary(
            planName: 'Pro',
            status: 'active',
            amountLabel: 'USD 12.50',
            renewalLabel: '2026-05-01',
            manageUrl: 'https://billing.example.com/manage',
          ),
        ),
        launcher: launcher,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('billing-success')), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('active'), findsOneWidget);
    expect(find.text('USD 12.50'), findsOneWidget);
    expect(find.text('2026-05-01'), findsOneWidget);
    expect(find.byKey(const ValueKey('billing-manage-action')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('billing-manage-action')));
    await tester.pumpAndSettle();

    expect(launcher.openedUrls, ['https://billing.example.com/manage']);
  });

  testWidgets('billing page keeps summary-only behavior without manageUrl', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        repository: const _FakeBillingRepository(
          summary: BillingSummary(planName: 'Starter', status: 'trialing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('billing-web-note')), findsOneWidget);
    expect(find.byKey(const ValueKey('billing-manage-action')), findsNothing);
    expect(
      find.text('This baseline shows your current subscription summary only.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'billing page shows fail-soft feedback when portal launch fails',
    (tester) async {
      final launcher = _FakeBillingPortalLauncher(shouldOpen: false);

      await tester.pumpWidget(
        _buildApp(
          repository: const _FakeBillingRepository(
            summary: BillingSummary(
              planName: 'Pro',
              status: 'active',
              manageUrl: 'https://billing.example.com/manage',
            ),
          ),
          launcher: launcher,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('billing-manage-action')));
      await tester.pumpAndSettle();

      expect(find.text('Could not open billing management.'), findsOneWidget);
      expect(launcher.openedUrls, ['https://billing.example.com/manage']);
    },
  );

  testWidgets('billing page shows retry state on failure', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        repository: const _FakeBillingRepository(
          failure: UnknownFailure(message: 'Billing failed', causeType: 'test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('billing-error')), findsOneWidget);
    expect(find.text('Billing failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

Widget _buildApp({
  required BillingRepository repository,
  BillingPortalLauncher? launcher,
}) {
  return ProviderScope(
    overrides: [
      billingRepositoryProvider.overrideWithValue(repository),
      if (launcher != null)
        billingPortalLauncherProvider.overrideWithValue(launcher),
    ],
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

class _FakeBillingPortalLauncher implements BillingPortalLauncher {
  _FakeBillingPortalLauncher({this.shouldOpen = true});

  final bool shouldOpen;
  final List<String> openedUrls = [];

  @override
  Future<bool> openManageUrl(String url) async {
    openedUrls.add(url);
    return shouldOpen;
  }
}
