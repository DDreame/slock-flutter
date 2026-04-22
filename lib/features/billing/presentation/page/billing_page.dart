import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/billing/application/billing_state.dart';
import 'package:slock_app/features/billing/application/billing_store.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';

class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key});

  @override
  ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(billingStoreProvider.notifier).ensureLoaded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingStoreProvider);

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
        BillingStatus.success => _BillingSuccess(summary: state.summary),
      },
    );
  }
}

class _BillingSuccess extends StatelessWidget {
  const _BillingSuccess({required this.summary});

  final BillingSummary? summary;

  @override
  Widget build(BuildContext context) {
    final effectiveSummary = summary ?? const BillingSummary();

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
          child: ListTile(
            key: const ValueKey('billing-web-note'),
            leading: const Icon(Icons.language),
            title: Text(
              effectiveSummary.manageUrl == null
                  ? 'Manage billing on the web'
                  : 'Web billing management is available',
            ),
            subtitle: Text(
              effectiveSummary.manageUrl == null
                  ? 'This baseline shows your current subscription summary only.'
                  : 'A manage/portal URL is present in the payload, but opening external billing flows stays out of scope here.',
            ),
          ),
        ),
      ],
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
