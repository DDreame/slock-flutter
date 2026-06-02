import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/utils/sender_label_l10n.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_card.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Quoted message block rendered inside a message bubble.
class QuotedMessageBlock extends StatelessWidget {
  const QuotedMessageBlock({
    super.key,
    required this.replyTo,
    required this.isSelf,
    this.onTap,
  });

  final ReplyToSummary replyTo;
  final bool isSelf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accentColor = isSelf
        ? colors.primaryForeground.withValues(alpha: 0.7)
        : colors.primary;
    final bgColor = isSelf
        ? colors.primaryForeground.withValues(alpha: 0.12)
        : colors.primary.withValues(alpha: 0.08);
    final labelColor = accentColor;
    final bodyColor = isSelf
        ? colors.primaryForeground.withValues(alpha: 0.85)
        : colors.textSecondary;

    return Semantics(
      button: onTap != null,
      label: onTap != null ? context.l10n.quotedMessageTapSemantics : null,
      child: GestureDetector(
        key: const ValueKey('quoted-message-tap'),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: accentColor, width: 3),
            ),
            color: bgColor,
            borderRadius: ConversationMessageCard.agentBadgeBorderRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                replyTo.localizedSenderLabel(context.l10n),
                style: ConversationMessageCard.senderNameBaseStyle.copyWith(
                  color: labelColor,
                ),
              ),
              Text(
                replyTo.content.isEmpty
                    ? context.l10n.conversationQuoteFallback
                    : replyTo.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: bodyColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
