import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/billing/application/billing_realtime_binding.dart';
import 'package:slock_app/features/billing/application/billing_state.dart';
import 'package:slock_app/features/billing/application/billing_store.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/presentation/billing_portal_launcher.dart';
import 'package:slock_app/features/billing/presentation/widgets/billing_action_card.dart';
import 'package:slock_app/features/billing/presentation/widgets/billing_management_section.dart';

class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key});

  @override
  ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  @override
  Widget build(BuildContext context) {
    ref.watch(billingRealtimeBindingProvider);
    final state = ref.watch(billingStoreProvider);
    if (state.status == BillingStatus.initial) {
      Future.microtask(
        () => ref.read(billingStoreProvider.notifier).ensureLoaded(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Billing')),
      body: switch (state.status) {
        BillingStatus.initial || BillingStatus.loading => const Center(
            key: ValueKey('billing-loading'),
            child: CircularProgressIndicator(),
          ),
        BillingStatus.failure => Center(
            key: const ValueKey('billing-error'),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.failure?.message ?? 'Could not load billing summary.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        ref.read(billingStoreProvider.notifier).load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        BillingStatus.success => _BillingSuccess(
            summary: state.summary,
            usage: state.usage,
            hasActiveServerScope: state.hasActiveServerScope,
            onOpenManagePortal: _openManagePortal,
          ),
      },
    );
  }

  Future<void> _openManagePortal(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened =
        await ref.read(billingPortalLauncherProvider).openManageUrl(url);
    if (!mounted || opened) {
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open billing management.')),
    );
  }
}

class _BillingSuccess extends StatelessWidget {
  const _BillingSuccess({
    required this.summary,
    required this.usage,
    required this.hasActiveServerScope,
    required this.onOpenManagePortal,
  });

  final BillingSummary? summary;
  final BillingUsageSummary? usage;
  final bool hasActiveServerScope;
  final ValueChanged<String> onOpenManagePortal;

  @override
  Widget build(BuildContext context) {
    final effectiveSummary = summary ?? const BillingSummary();
    final effectiveUsage = usage;
    final manageUrl = effectiveSummary.manageUrl;

    return ListView(
      key: const ValueKey('billing-success'),
      padding: const EdgeInsets.all(16),
      children: [
        BillingManagementSection(
          key: const ValueKey('billing-subscription-section'),
          title: 'Subscription management',
          description:
              'Review your current subscription and open the billing portal when management is available.',
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      effectiveSummary.planName ?? 'Subscription summary',
                      key: const ValueKey('billing-plan-name'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      effectiveSummary.status ?? 'Status unavailable',
                      key: const ValueKey('billing-status'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (effectiveSummary.amountLabel != null)
                      _BillingDetailRow(
                        label: 'Current price',
                        value: effectiveSummary.amountLabel!,
                      ),
                    if (effectiveSummary.renewalLabel != null)
                      _BillingDetailRow(
                        label: 'Renewal / period',
                        value: effectiveSummary.renewalLabel!,
                      ),
                    if (effectiveSummary.isEmpty)
                      const Text('Billing details are not available yet.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            BillingActionCard(
              cardKey: ValueKey(
                manageUrl == null
                    ? 'billing-management-unavailable'
                    : 'billing-manage-card',
              ),
              icon: manageUrl == null ? Icons.info_outline : Icons.open_in_new,
              title: manageUrl == null
                  ? 'Billing management unavailable'
                  : 'Open billing portal',
              message: manageUrl == null
                  ? 'Billing management is not available for this workspace yet. Subscription details will continue to appear here when provided by the server.'
                  : 'Manage your subscription with the billing portal.',
              actionKey: manageUrl == null
                  ? null
                  : const ValueKey('billing-manage-action'),
              actionLabel: manageUrl == null ? null : 'Open billing portal',
              onAction: manageUrl == null
                  ? null
                  : () => onOpenManagePortal(manageUrl),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BillingManagementSection(
          key: const ValueKey('billing-workspace-section'),
          title: 'Workspace plan management',
          description: hasActiveServerScope
              ? 'Review current workspace limits and any upgrade or downgrade guidance.'
              : 'Select a workspace to review server-scoped billing limits and plan guidance.',
          children: [
            _BillingUsageSection(
              summary: effectiveSummary,
              usage: effectiveUsage,
              hasActiveServerScope: hasActiveServerScope,
              onOpenManagePortal: manageUrl == null
                  ? null
                  : () => onOpenManagePortal(manageUrl),
            ),
          ],
        ),
      ],
    );
  }
}

class _BillingUsageSection extends StatelessWidget {
  const _BillingUsageSection({
    required this.summary,
    required this.usage,
    required this.hasActiveServerScope,
    required this.onOpenManagePortal,
  });

  final BillingSummary summary;
  final BillingUsageSummary? usage;
  final bool hasActiveServerScope;
  final VoidCallback? onOpenManagePortal;

  @override
  Widget build(BuildContext context) {
    if (!hasActiveServerScope) {
      return const BillingActionCard(
        cardKey: ValueKey('billing-usage-select-server'),
        icon: Icons.dns_outlined,
        title: 'Workspace plan requires a selected workspace',
        message:
            'Select a workspace to see current usage, plan limits, and upgrade guidance.',
      );
    }

    if (usage == null || usage!.isEmpty) {
      return const BillingActionCard(
        cardKey: ValueKey('billing-usage-unavailable'),
        icon: Icons.bar_chart_outlined,
        title: 'Workspace usage unavailable',
        message: 'Usage details are unavailable right now.',
      );
    }

    final effectiveUsage = usage!;
    final usageChildren = <Widget>[
      Card(
        key: const ValueKey('billing-usage-card'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Server usage and limits',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                effectiveUsage.planName ?? 'Plan details unavailable',
                key: const ValueKey('billing-usage-plan-name'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (effectiveUsage.planCode != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    effectiveUsage.planCode!.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              const SizedBox(height: 16),
              for (final resource in effectiveUsage.resources)
                _BillingUsageRow(resource: resource),
              if (effectiveUsage.messageHistoryDays != null)
                _BillingDetailRow(
                  label: 'Message history',
                  value: _formatMessageHistoryDays(
                    effectiveUsage.messageHistoryDays!,
                  ),
                ),
            ],
          ),
        ),
      ),
    ];

    if (effectiveUsage.planDowngradedAt != null) {
      usageChildren.addAll([
        const SizedBox(height: 12),
        BillingActionCard(
          cardKey: const ValueKey('billing-plan-downgraded'),
          icon: Icons.warning_amber_rounded,
          title: 'Workspace plan downgraded',
          message:
              'This workspace plan was downgraded on ${effectiveUsage.planDowngradedAt}. Upgrade to restore higher limits.',
          actionLabel: summary.manageUrl == null ? null : 'Open billing portal',
          onAction: onOpenManagePortal,
        ),
      ]);
    } else if (effectiveUsage.hasUpgradePrompt) {
      usageChildren.addAll([
        const SizedBox(height: 12),
        BillingActionCard(
          cardKey: const ValueKey('billing-upgrade-prompt'),
          icon: Icons.upgrade,
          title: 'Need more capacity?',
          message: summary.manageUrl != null
              ? 'Open the billing portal to review upgrade options for this workspace plan.'
              : 'Upgrade options will appear here when billing management is available for this workspace.',
          actionLabel: summary.manageUrl == null ? null : 'Open billing portal',
          onAction: onOpenManagePortal,
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: usageChildren,
    );
  }
}

class _BillingDetailRow extends StatelessWidget {
  const _BillingDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}

class _BillingUsageRow extends StatelessWidget {
  const _BillingUsageRow({required this.resource});

  final BillingUsageResource resource;

  @override
  Widget build(BuildContext context) {
    final value = resource.hasFiniteLimit
        ? '${resource.used} / ${resource.limit}'
        : '${resource.used}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              resource.label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Text(
            value,
            key: ValueKey('billing-usage-${resource.label.toLowerCase()}'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: resource.atOrOverLimit
                      ? Theme.of(context).colorScheme.error
                      : null,
                  fontWeight: resource.atOrOverLimit ? FontWeight.w600 : null,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatMessageHistoryDays(int days) {
  if (days < 0) {
    return 'Unlimited';
  }
  if (days == 1) {
    return '1 day';
  }
  return '$days days';
}
