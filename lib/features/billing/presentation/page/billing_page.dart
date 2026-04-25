import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/billing/application/billing_realtime_binding.dart';
import 'package:slock_app/features/billing/application/billing_state.dart';
import 'package:slock_app/features/billing/application/billing_store.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/presentation/billing_portal_launcher.dart';

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

    return ListView(
      key: const ValueKey('billing-success'),
      padding: const EdgeInsets.all(16),
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
        Card(
          child: effectiveSummary.manageUrl == null
              ? const ListTile(
                  key: ValueKey('billing-web-note'),
                  leading: Icon(Icons.language),
                  title: Text('Manage billing on the web'),
                  subtitle: Text(
                    'This baseline shows your current subscription summary only.',
                  ),
                )
              : ListTile(
                  key: const ValueKey('billing-manage-action'),
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Open billing portal'),
                  subtitle: const Text(
                    'Manage your subscription with the web billing portal.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpenManagePortal(effectiveSummary.manageUrl!),
                ),
        ),
        const SizedBox(height: 12),
        _BillingUsageCard(
          summary: effectiveSummary,
          usage: effectiveUsage,
          hasActiveServerScope: hasActiveServerScope,
        ),
      ],
    );
  }
}

class _BillingUsageCard extends StatelessWidget {
  const _BillingUsageCard({
    required this.summary,
    required this.usage,
    required this.hasActiveServerScope,
  });

  final BillingSummary summary;
  final BillingUsageSummary? usage;
  final bool hasActiveServerScope;

  @override
  Widget build(BuildContext context) {
    if (!hasActiveServerScope) {
      return const Card(
        child: ListTile(
          key: ValueKey('billing-usage-select-server'),
          leading: Icon(Icons.dns_outlined),
          title: Text('Server usage and limits'),
          subtitle: Text(
            'Select a server to see current usage and plan limits.',
          ),
        ),
      );
    }

    if (usage == null || usage!.isEmpty) {
      return const Card(
        child: ListTile(
          key: ValueKey('billing-usage-unavailable'),
          leading: Icon(Icons.bar_chart_outlined),
          title: Text('Server usage and limits'),
          subtitle: Text('Usage details are unavailable right now.'),
        ),
      );
    }

    final effectiveUsage = usage!;

    return Card(
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
            if (effectiveUsage.planDowngradedAt != null) ...[
              const SizedBox(height: 8),
              _BillingUsagePrompt(
                key: const ValueKey('billing-plan-downgraded'),
                message:
                    'This server plan was downgraded on ${effectiveUsage.planDowngradedAt}. Upgrade to restore higher limits.',
              ),
            ] else if (effectiveUsage.hasUpgradePrompt) ...[
              const SizedBox(height: 8),
              _BillingUsagePrompt(
                key: const ValueKey('billing-upgrade-prompt'),
                message: summary.manageUrl != null
                    ? 'Need more capacity? Open the billing portal to upgrade this server plan.'
                    : 'Need more capacity? Upgrade options will appear here when billing management is available.',
              ),
            ],
          ],
        ),
      ),
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

class _BillingUsagePrompt extends StatelessWidget {
  const _BillingUsagePrompt({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.upgrade, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
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
