import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_status_tokens.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_card.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Pill badge showing the linked task status and number in a message header.
class MessageLinkedTaskBadge extends StatelessWidget {
  const MessageLinkedTaskBadge({
    super.key,
    required this.task,
    required this.serverId,
  });

  final ConversationLinkedTaskSummary task;
  final String serverId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, tone) = switch (task.status) {
      'todo' => (Icons.radio_button_unchecked, AppStatusTone.neutral),
      'in_progress' => (Icons.timelapse, AppStatusTone.info),
      'in_review' => (Icons.rate_review, AppStatusTone.warning),
      'done' => (Icons.check_circle, AppStatusTone.success),
      _ => (Icons.circle_outlined, AppStatusTone.neutral),
    };
    final colors = appStatusColors(theme.colorScheme, tone);
    final label = StringBuffer('#${task.taskNumber}');
    if (task.claimedByName != null && task.claimedByName!.isNotEmpty) {
      label.write(' @${task.claimedByName}');
    }

    // Absorb taps and navigate to the tasks page so they don't
    // bubble up to the message card's thread-navigation GestureDetector.
    return Semantics(
      button: true,
      label: context.l10n.linkedTaskBadgeSemantics,
      child: GestureDetector(
        onTap: () => context.push('/servers/$serverId/tasks'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          key: ValueKey('message-linked-task-${task.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colors.container,
            border: Border.all(color: colors.foreground),
            borderRadius: ConversationMessageCard.taskBadgeBorderRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: colors.onContainer),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label.toString(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
