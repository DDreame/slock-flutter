import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/widgets/status_glow_ring.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// Helper functions and shared widgets extracted from agents_page.dart.
// ---------------------------------------------------------------------------

/// Maps [AgentItem.activity] string to [GlowRingStatus].
GlowRingStatus mapActivityToGlowStatus(String activity) {
  return switch (activity) {
    'online' => GlowRingStatus.online,
    'thinking' => GlowRingStatus.thinking,
    'working' => GlowRingStatus.working,
    'error' => GlowRingStatus.error,
    'offline' => GlowRingStatus.offline,
    _ => GlowRingStatus.offline,
  };
}

/// Returns localized activity label for an agent's current activity.
String agentActivityLabel(
  String activity,
  String? detail,
  AppLocalizations l10n,
) {
  return switch (activity) {
    'online' => l10n.agentsActivityOnline,
    'thinking' => l10n.agentsActivityThinking,
    'working' => detail ?? l10n.agentsActivityWorking,
    'error' => detail != null
        ? l10n.agentsActivityErrorDetail(detail)
        : l10n.agentsActivityError,
    'offline' => l10n.agentsActivityOffline,
    _ => activity,
  };
}

/// Shared failure view used by both the list page and detail scaffold.
class AgentsFailureView extends StatelessWidget {
  const AgentsFailureView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.agentsRetry),
            ),
          ],
        ),
      ),
    );
  }
}
