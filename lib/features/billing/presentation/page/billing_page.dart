import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/widgets/friendly_error_state.dart';
import 'package:slock_app/core/telemetry/diagnostic_share_sheet.dart';
import 'package:slock_app/features/billing/application/billing_realtime_binding.dart';
import 'package:slock_app/features/billing/application/billing_state.dart';
import 'package:slock_app/features/billing/application/billing_store.dart';
import 'package:slock_app/features/billing/data/billing_repository.dart';
import 'package:slock_app/features/billing/presentation/billing_portal_launcher.dart';
import 'package:slock_app/features/billing/presentation/widgets/billing_action_card.dart';
import 'package:slock_app/features/billing/presentation/widgets/billing_management_section.dart';
import 'package:slock_app/l10n/l10n.dart';

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
      appBar: AppBar(title: Text(context.l10n.billingTitle)),
      body: switch (state.status) {
        BillingStatus.initial || BillingStatus.loading => const Center(
            key: ValueKey('billing-loading'),
            child: CircularProgressIndicator(),
          ),
        BillingStatus.failure => FriendlyErrorState(
            key: const ValueKey('billing-error'),
            title: context.l10n.billingUnavailableTitle,
            message: context.l10n.billingUnavailableMessage,
            onRetry: ref.read(billingStoreProvider.notifier).load,
            onShareDiagnostics: () => DiagnosticShareSheet.show(context),
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
      SnackBar(content: Text(context.l10n.billingCouldNotOpenManagement)),
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
    final l10n = context.l10n;
    final effectiveSummary = summary ?? const BillingSummary();
    final effectiveUsage = usage;
    final manageUrl = effectiveSummary.manageUrl;

    return ListView(
      key: const ValueKey('billing-success'),
      padding: const EdgeInsets.all(16),
      children: [
        BillingManagementSection(
          key: const ValueKey('billing-subscription-section'),
          title: l10n.billingSubscriptionManagement,
          description: l10n.billingSubscriptionManagementDesc,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      effectiveSummary.planName ??
                          l10n.billingSubscriptionSummary,
                      key: const ValueKey('billing-plan-name'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      effectiveSummary.status ?? l10n.billingStatusUnavailable,
                      key: const ValueKey('billing-status'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (effectiveSummary.amountLabel != null)
                      _BillingDetailRow(
                        label: l10n.billingCurrentPrice,
                        value: effectiveSummary.amountLabel!,
                      ),
                    if (effectiveSummary.renewalLabel != null)
                      _BillingDetailRow(
                        label: l10n.billingRenewalPeriod,
                        value: effectiveSummary.renewalLabel!,
                      ),
                    if (effectiveSummary.isEmpty)
                      Text(l10n.billingDetailsNotAvailable),
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
                  ? l10n.billingManagementUnavailable
                  : l10n.billingOpenPortal,
              message: manageUrl == null
                  ? l10n.billingManagementUnavailableMessage
                  : l10n.billingManageSubscription,
              actionKey: manageUrl == null
                  ? null
                  : const ValueKey('billing-manage-action'),
              actionLabel: manageUrl == null ? null : l10n.billingOpenPortal,
              onAction: manageUrl == null
                  ? null
                  : () => onOpenManagePortal(manageUrl),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BillingManagementSection(
          key: const ValueKey('billing-workspace-section'),
          title: l10n.billingWorkspacePlanManagement,
          description: hasActiveServerScope
              ? l10n.billingWorkspacePlanDescActive
              : l10n.billingWorkspacePlanDescSelect,
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
    final l10n = context.l10n;
    if (!hasActiveServerScope) {
      return BillingActionCard(
        cardKey: const ValueKey('billing-usage-select-server'),
        icon: Icons.dns_outlined,
        title: l10n.billingUsageSelectWorkspace,
        message: l10n.billingUsageSelectWorkspaceMessage,
      );
    }

    if (usage == null || usage!.isEmpty) {
      return BillingActionCard(
        cardKey: const ValueKey('billing-usage-unavailable'),
        icon: Icons.bar_chart_outlined,
        title: l10n.billingUsageUnavailableTitle,
        message: l10n.billingUsageUnavailableMessage,
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
                l10n.billingServerUsageAndLimits,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                effectiveUsage.planName ?? l10n.billingPlanDetailsUnavailable,
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
                  label: l10n.billingMessageHistory,
                  value: _formatMessageHistoryDays(
                    effectiveUsage.messageHistoryDays!,
                    l10n,
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
          title: l10n.billingPlanDowngraded,
          message: l10n
              .billingPlanDowngradedMessage(effectiveUsage.planDowngradedAt!),
          actionLabel:
              summary.manageUrl == null ? null : l10n.billingOpenPortal,
          onAction: onOpenManagePortal,
        ),
      ]);
    } else if (effectiveUsage.hasUpgradePrompt) {
      usageChildren.addAll([
        const SizedBox(height: 12),
        BillingActionCard(
          cardKey: const ValueKey('billing-upgrade-prompt'),
          icon: Icons.upgrade,
          title: l10n.billingNeedMoreCapacity,
          message: summary.manageUrl != null
              ? l10n.billingUpgradePortalMessage
              : l10n.billingUpgradeUnavailableMessage,
          actionLabel:
              summary.manageUrl == null ? null : l10n.billingOpenPortal,
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
    final localizedLabel = _localizeResourceLabel(context, resource.label);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              localizedLabel,
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

String _formatMessageHistoryDays(int days, AppLocalizations l10n) {
  if (days < 0) {
    return l10n.billingMessageHistoryUnlimited;
  }
  if (days == 1) {
    return l10n.billingMessageHistoryOneDay;
  }
  return l10n.billingMessageHistoryDays(days);
}

/// Maps repository-layer resource labels to localized display strings.
String _localizeResourceLabel(BuildContext context, String label) {
  final l10n = context.l10n;
  return switch (label) {
    'Agents' => l10n.billingResourceAgents,
    'Machines' => l10n.billingResourceMachines,
    'Channels' => l10n.billingResourceChannels,
    _ => label,
  };
}
