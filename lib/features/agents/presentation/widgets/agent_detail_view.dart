import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/app_loading_indicator.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/app/widgets/status_glow_ring.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page_helpers.dart';
import 'package:slock_app/features/presence/presentation/widgets/presence_avatar.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// Agent detail view extracted from agents_page.dart.
// ---------------------------------------------------------------------------

class AgentDetailScaffold extends StatelessWidget {
  const AgentDetailScaffold({
    super.key,
    required this.agent,
    required this.isLoading,
    required this.isFailure,
    required this.failureMessage,
    required this.onRetry,
    required this.onEdit,
    required this.onDelete,
    required this.onStart,
    required this.onStop,
    required this.onReset,
    required this.onMessage,
  });

  final AgentItem? agent;
  final bool isLoading;
  final bool isFailure;
  final String? failureMessage;
  final VoidCallback onRetry;
  final Future<void> Function(AgentItem)? onEdit;
  final Future<void> Function(AgentItem)? onDelete;
  final Future<void> Function(AgentItem)? onStart;
  final Future<void> Function(AgentItem)? onStop;
  final Future<void> Function(AgentItem)? onReset;
  final Future<void> Function(AgentItem)? onMessage;

  @override
  Widget build(BuildContext context) {
    if (agent == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.agentsAppBarTitle)),
        body: isLoading
            ? const AppLoadingIndicator()
            : isFailure
                ? AgentsFailureView(
                    message: failureMessage ?? context.l10n.agentsFailedToLoad,
                    onRetry: onRetry,
                  )
                : Center(child: Text(context.l10n.agentsNotFound)),
      );
    }

    final a = agent!;
    return Scaffold(
      appBar: AppBar(
        title: Text(a.label),
        actions: [
          IconButton(
            key: const ValueKey('agent-edit-btn'),
            onPressed: onEdit == null ? null : () => onEdit!(a),
            icon: const Icon(Icons.edit_outlined),
            tooltip: context.l10n.agentEditTooltip,
          ),
          IconButton(
            key: const ValueKey('agent-delete-btn'),
            onPressed: onDelete == null ? null : () => onDelete!(a),
            icon: const Icon(Icons.delete_outline),
            tooltip: context.l10n.agentDeleteTooltip,
          ),
        ],
      ),
      body: AgentDetailBody(
        agent: a,
        onStart: onStart,
        onStop: onStop,
        onReset: onReset,
        onMessage: onMessage,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity log loader
// ---------------------------------------------------------------------------

/// Triggers the initial REST load of the activity log for [agentId].
/// Auto-disposed when the detail view is removed from the tree.
final agentActivityLogLoaderProvider =
    FutureProvider.autoDispose.family<void, String>((ref, agentId) async {
  await ref.read(agentsStoreProvider.notifier).loadActivityLog(agentId);
});

// ---------------------------------------------------------------------------
// Agent detail body
// ---------------------------------------------------------------------------

class AgentDetailBody extends ConsumerWidget {
  const AgentDetailBody({
    super.key,
    required this.agent,
    required this.onStart,
    required this.onStop,
    required this.onReset,
    required this.onMessage,
  });

  final AgentItem agent;
  final Future<void> Function(AgentItem)? onStart;
  final Future<void> Function(AgentItem)? onStop;
  final Future<void> Function(AgentItem)? onReset;
  final Future<void> Function(AgentItem)? onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      children: [
        _AgentHeader(
          key: ValueKey('agent-header-${agent.id}'),
          agent: agent,
          colors: colors,
        ),
        const SizedBox(height: AppSpacing.xl),
        _ActionButtonRow(
          agent: agent,
          colors: colors,
          onMessage: onMessage,
          onStart: onStart,
          onStop: onStop,
          onReset: onReset,
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        _ConfigGrid(
          key: const ValueKey('agent-config-grid'),
          agent: agent,
          colors: colors,
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        _EnvVarsSection(
          key: const ValueKey('agent-env-vars-section'),
          colors: colors,
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        _ActivityLogSection(
          key: const ValueKey('agent-activity-log-section'),
          agentId: agent.id,
          colors: colors,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Agent header (avatar + status + description)
// ---------------------------------------------------------------------------

class _AgentHeader extends StatelessWidget {
  const _AgentHeader({
    super.key,
    required this.agent,
    required this.colors,
  });

  final AgentItem agent;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: StatusGlowRing(
            key: const ValueKey('agent-detail-glow-ring'),
            status: mapActivityToGlowStatus(agent.activity),
            size: 80,
            child: PresenceAvatar(
              key: ValueKey('agent-detail-presence-${agent.id}'),
              userId: agent.id,
              child: CircleAvatar(
                radius: 34,
                backgroundColor: colors.surfaceAlt,
                child: Text(
                  agent.label.isNotEmpty ? agent.label[0].toUpperCase() : '?',
                  style: AppTypography.displayMedium.copyWith(
                    color: colors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            agentActivityLabel(
                agent.activity, agent.activityDetail, context.l10n),
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        if (agent.description != null && agent.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              agent.description!,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Activity log section — loaded lazily via provider
// ---------------------------------------------------------------------------

class _ActivityLogSection extends ConsumerWidget {
  const _ActivityLogSection({
    super.key,
    required this.agentId,
    required this.colors,
  });

  final String agentId;
  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger REST load only when this section builds (not eagerly in parent).
    final activityLogAsync = ref.watch(agentActivityLogLoaderProvider(agentId));

    final activityLog = ref.watch(
      agentsStoreProvider.select((state) => state.activityLogFor(agentId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.agentsActivityLogTitle,
          style: AppTypography.title.copyWith(color: colors.text),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (activityLogAsync.hasError && activityLog.isEmpty)
          Text(
            context.l10n.agentsActivityLogLoadFailed,
            key: const ValueKey('agent-activity-log-error'),
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          )
        else if (activityLog.isEmpty)
          Text(
            context.l10n.agentsActivityLogEmpty,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          )
        else
          for (final entry in activityLog)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTime(entry.timestamp),
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textTertiary,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.entry,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Action buttons
// ---------------------------------------------------------------------------

class _ActionButtonRow extends StatelessWidget {
  const _ActionButtonRow({
    required this.agent,
    required this.colors,
    required this.onMessage,
    required this.onStart,
    required this.onStop,
    required this.onReset,
  });

  final AgentItem agent;
  final AppColors colors;
  final Future<void> Function(AgentItem)? onMessage;
  final Future<void> Function(AgentItem)? onStart;
  final Future<void> Function(AgentItem)? onStop;
  final Future<void> Function(AgentItem)? onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        // Message — primary filled
        FilledButton.icon(
          key: const ValueKey('agent-message-btn'),
          onPressed: onMessage == null ? null : () => onMessage!(agent),
          icon: const Icon(Icons.message_outlined),
          label: Text(l10n.agentsActionMessage),
        ),
        if (agent.isStopped)
          FilledButton.icon(
            key: const ValueKey('agent-start-btn'),
            onPressed: onStart == null ? null : () => onStart!(agent),
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.agentsActionStart),
          ),
        if (agent.isActive)
          OutlinedButton.icon(
            key: const ValueKey('agent-stop-btn'),
            onPressed: onStop == null ? null : () => onStop!(agent),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error),
            ),
            icon: const Icon(Icons.stop),
            label: Text(l10n.agentsActionStop),
          ),
        if (agent.isActive)
          OutlinedButton.icon(
            key: const ValueKey('agent-reset-btn'),
            onPressed: onReset == null ? null : () => onReset!(agent),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.agentsActionReset),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2x2 Config grid
// ---------------------------------------------------------------------------

class _ConfigGrid extends StatelessWidget {
  const _ConfigGrid({
    super.key,
    required this.agent,
    required this.colors,
  });

  final AgentItem agent;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ConfigCell(
                label: l10n.agentsConfigMachine,
                value: agent.machineId ?? '-',
                colors: colors,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ConfigCell(
                label: l10n.agentsConfigRuntime,
                value: agent.runtime,
                colors: colors,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ConfigCell(
                label: l10n.agentsConfigModel,
                value: agent.model,
                colors: colors,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ConfigCell(
                label: l10n.agentsConfigReasoning,
                value: agent.reasoningEffort ?? '-',
                colors: colors,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConfigCell extends StatelessWidget {
  const _ConfigCell({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.body.copyWith(color: colors.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Environment Variables section
// ---------------------------------------------------------------------------

/// Read-only stub for the environment variables section.
///
/// Currently displays an "empty" placeholder regardless of the agent's actual
/// env vars. The full editing flow is handled by [AgentFormDialog] — this
/// detail view intentionally omits inline editing to keep env vars (which may
/// contain secrets) behind the explicit form flow.
///
/// To implement real display here, accept the agent's `envVars` map and
/// enumerate key names (values should remain masked for security).
class _EnvVarsSection extends StatelessWidget {
  const _EnvVarsSection({super.key, required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.agentsEnvVarsTitle,
                style: AppTypography.title.copyWith(color: colors.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SectionCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              context.l10n.agentsEnvVarsEmpty,
              key: const ValueKey('agent-env-vars-empty'),
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
