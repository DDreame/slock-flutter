import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/data/billing_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/billing/presentation/billing_portal_launcher.dart';
import 'package:slock_app/features/billing/presentation/page/billing_page.dart';

void main() {
  testWidgets('billing page shows subscription summary and server usage', (
    tester,
  ) async {
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
          usage: BillingUsageSummary(
            planCode: 'free',
            planName: 'Hobby',
            messageHistoryDays: 30,
            resources: [
              BillingUsageResource(label: 'Agents', used: 1, limit: 1),
              BillingUsageResource(label: 'Machines', used: 2, limit: 4),
              BillingUsageResource(label: 'Channels', used: 3, limit: 10),
            ],
          ),
        ),
        launcher: launcher,
        activeServerScopeId: const ServerScopeId('server-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('billing-success')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('billing-subscription-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('billing-workspace-section')),
      findsOneWidget,
    );
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('active'), findsOneWidget);
    expect(find.text('USD 12.50'), findsOneWidget);
    expect(find.text('2026-05-01'), findsOneWidget);
    expect(find.byKey(const ValueKey('billing-manage-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('billing-usage-card')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('billing-usage-plan-name')),
      findsOneWidget,
    );
    expect(find.text('Hobby'), findsOneWidget);
    expect(find.byKey(const ValueKey('billing-usage-agents')), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('billing-upgrade-prompt')),
      findsOneWidget,
    );
    expect(find.text('30 days'), findsOneWidget);

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

    expect(
      find.byKey(const ValueKey('billing-management-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('billing-manage-action')), findsNothing);
    expect(
      find.byKey(const ValueKey('billing-usage-select-server')),
      findsOneWidget,
    );
    expect(
      find.text(
          'Billing management is not available for this workspace yet. Subscription details will continue to appear here when provided by the server.'),
      findsOneWidget,
    );
  });

  testWidgets('billing page shows fail-soft usage note when usage read fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        repository: const _FakeBillingRepository(
          summary: BillingSummary(
            planName: 'Pro',
            status: 'active',
            manageUrl: 'https://billing.example.com/manage',
          ),
          usageFailure: UnknownFailure(
            message: 'Usage failed',
            causeType: 'test',
          ),
        ),
        activeServerScopeId: const ServerScopeId('server-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('billing-success')), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('billing-usage-unavailable')),
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
  ServerScopeId? activeServerScopeId,
}) {
  return ProviderScope(
    overrides: [
      billingRepositoryProvider.overrideWithValue(repository),
      if (activeServerScopeId != null)
        activeServerScopeIdProvider.overrideWithValue(activeServerScopeId),
      if (launcher != null)
        billingPortalLauncherProvider.overrideWithValue(launcher),
    ],
    child: const MaterialApp(home: BillingPage()),
  );
}

class _FakeBillingRepository implements BillingRepository {
  const _FakeBillingRepository({
    this.summary,
    this.usage,
    this.failure,
    this.usageFailure,
  });

  final BillingSummary? summary;
  final BillingUsageSummary? usage;
  final AppFailure? failure;
  final AppFailure? usageFailure;

  @override
  Future<BillingSummary> loadSubscription() async {
    if (failure != null) {
      throw failure!;
    }
    return summary ?? const BillingSummary();
  }

  @override
  Future<BillingUsageSummary> loadServerUsage(ServerScopeId serverId) async {
    if (usageFailure != null) {
      throw usageFailure!;
    }
    return usage ?? const BillingUsageSummary();
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
