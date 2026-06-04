import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/l10n/app_localizations.dart';

/// Standardized display status for agent UI surfaces.
///
/// Values are ordered by display priority (highest first).
/// Use [resolveDisplayStatus] to map from [AgentItem] raw strings.
enum AgentDisplayStatus {
  thinking,
  working,
  error,
  online,
  offline,
  stopped,
}

/// Resolves the canonical display status for an agent.
///
/// Stopped agents always resolve to [AgentDisplayStatus.stopped]
/// regardless of any stale activity value. Active agents resolve
/// by their current activity string.
AgentDisplayStatus resolveDisplayStatus(AgentItem agent) {
  if (agent.isStopped) return AgentDisplayStatus.stopped;
  return switch (agent.activity) {
    'thinking' => AgentDisplayStatus.thinking,
    'working' => AgentDisplayStatus.working,
    'error' => AgentDisplayStatus.error,
    'online' || 'idle' => AgentDisplayStatus.online,
    _ => AgentDisplayStatus.offline,
  };
}

/// Returns the sort priority for a display status.
/// Lower values are higher priority (shown first).
int displayStatusPriority(AgentDisplayStatus status) => status.index;

/// Returns the localized display label for a status.
///
/// Resolves the label through the ARB l10n system.
String displayStatusLabel(
  AgentDisplayStatus status, {
  required AppLocalizations l10n,
}) {
  return switch (status) {
    AgentDisplayStatus.thinking => l10n.agentStatusThinking,
    AgentDisplayStatus.working => l10n.agentStatusWorking,
    AgentDisplayStatus.error => l10n.agentStatusError,
    AgentDisplayStatus.online => l10n.agentStatusOnline,
    AgentDisplayStatus.offline => l10n.agentStatusOffline,
    AgentDisplayStatus.stopped => l10n.agentStatusStopped,
  };
}
