import 'package:slock_app/features/agents/data/agent_item.dart';

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
    'online' => AgentDisplayStatus.online,
    _ => AgentDisplayStatus.offline,
  };
}

/// Returns the sort priority for a display status.
/// Lower values are higher priority (shown first).
int displayStatusPriority(AgentDisplayStatus status) => status.index;

/// Returns the Chinese display label for a status.
///
/// Hardcoded per PM decision — will be extracted to l10n later.
String displayStatusLabel(AgentDisplayStatus status) {
  return switch (status) {
    AgentDisplayStatus.thinking => '思考中',
    AgentDisplayStatus.working => '工作中',
    AgentDisplayStatus.error => '错误',
    AgentDisplayStatus.online => '在线',
    AgentDisplayStatus.offline => '离线',
    AgentDisplayStatus.stopped => '已停止',
  };
}
