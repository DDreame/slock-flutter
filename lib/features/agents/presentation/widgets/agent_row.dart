import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/list_action_sheet.dart';
import 'package:slock_app/app/widgets/role_badge.dart';
import 'package:slock_app/app/widgets/status_glow_ring.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page_helpers.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// Agent row widget extracted from agents_page.dart.
// ---------------------------------------------------------------------------

class AgentRow extends StatelessWidget {
  const AgentRow({
    super.key,
    required this.agent,
    required this.colors,
    required this.onTap,
    required this.onStart,
    required this.onStop,
    required this.onReset,
  });

  final AgentItem agent;
  final AppColors colors;
  final void Function(AgentItem) onTap;
  final Future<void> Function(AgentItem) onStart;
  final Future<void> Function(AgentItem) onStop;
  final Future<void> Function(AgentItem) onReset;

  @override
  Widget build(BuildContext context) {
    final isStopped = agent.isStopped;
    final l10n = context.l10n;
    final activityText =
        agentActivityLabel(agent.activity, agent.activityDetail, l10n);

    Widget row = Semantics(
      button: true,
      label: l10n.agentsRowSemantics(agent.label, activityText),
      onLongPressHint: l10n.agentsRowActionsHint,
      child: InkWell(
        key: ValueKey('agent-${agent.id}'),
        onTap: () => onTap(agent),
        onLongPress: () => _showAgentActions(context),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.listItemVertical,
            ),
            child: Row(
              children: [
                StatusGlowRing(
                  status: mapActivityToGlowStatus(agent.activity,
                      isStopped: agent.isStopped),
                  size: 44,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.surfaceAlt,
                    child: Text(
                      agent.label.isNotEmpty
                          ? agent.label[0].toUpperCase()
                          : '?',
                      style: AppTypography.title.copyWith(color: colors.text),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              agent.label,
                              style: AppTypography.title.copyWith(
                                color: colors.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          RoleBadge(
                            label: agent.runtime,
                            color: colors.agentAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activityText,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (isStopped) {
      row = Opacity(
        key: ValueKey('agent-row-opacity-${agent.id}'),
        opacity: 0.5,
        child: row,
      );
    }

    return row;
  }

  Future<void> _showAgentActions(BuildContext context) async {
    final l10n = context.l10n;
    final actions = <ListActionItem>[
      if (agent.isStopped)
        ListActionItem(
          key: 'agent-action-start',
          label: l10n.agentsActionStart,
          icon: Icons.play_arrow,
        ),
      if (agent.isActive)
        ListActionItem(
          key: 'agent-action-stop',
          label: l10n.agentsActionStop,
          icon: Icons.stop,
        ),
      if (agent.isActive)
        ListActionItem(
          key: 'agent-action-reset',
          label: l10n.agentsActionResetSession,
          icon: Icons.refresh,
        ),
    ];

    final result = await showListActionSheet(
      context: context,
      actions: actions,
      title: agent.label,
    );

    switch (result) {
      case 'agent-action-start':
        onStart(agent);
      case 'agent-action-stop':
        onStop(agent);
      case 'agent-action-reset':
        onReset(agent);
    }
  }
}
