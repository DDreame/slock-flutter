import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/markdown_message_body.dart';
import 'package:slock_app/features/conversation/presentation/widgets/mention_syntax.dart';

/// Public widget that renders message content, routing between
/// Markdown rendering for non-system messages and plain italic
/// text for system messages.
///
/// This widget is the integration point between the conversation
/// detail page and the Markdown rendering pipeline.
class MessageContentWidget extends StatelessWidget {
  const MessageContentWidget({
    super.key,
    required this.message,
    this.isSystem = false,
    this.kind = MessageBubbleKind.other,
    this.highlightQuery = '',
    this.baseStyle,
    this.highlightColor,
    this.onLinkTap,
    this.currentUserName,
  });

  final ConversationMessageSummary message;
  final bool isSystem;
  final MessageBubbleKind kind;
  final String highlightQuery;
  final TextStyle? baseStyle;
  final Color? highlightColor;
  final void Function(String text, String? href, String title)? onLinkTap;

  /// The current user's display name for self-mention highlighting.
  final String? currentUserName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    final effectiveBaseStyle = baseStyle ??
        (isSystem
            ? AppTypography.body.copyWith(
                color: colors.textSecondary,
                fontStyle: FontStyle.italic,
              )
            : AppTypography.body.copyWith(color: colors.text));

    // System messages: plain text, no Markdown rendering.
    if (isSystem) {
      if (highlightQuery.isNotEmpty) {
        return Text.rich(
          buildMentionAwareSpan(
            text: message.content,
            baseStyle: effectiveBaseStyle,
            mentionColor: colors.primary,
            mentionBackground: colors.primary.withValues(alpha: 0.1),
            selfMentionColor: colors.primaryForeground,
            selfMentionBackground: colors.primary,
            currentUserName: currentUserName,
            highlightQuery: highlightQuery,
            highlightColor: highlightColor ?? colors.primaryLight,
          ),
          key: const ValueKey('message-content'),
        );
      }
      return Text.rich(
        buildMentionAwareSpan(
          text: message.content,
          baseStyle: effectiveBaseStyle,
          mentionColor: colors.primary,
          mentionBackground: colors.primary.withValues(alpha: 0.1),
          selfMentionColor: colors.primaryForeground,
          selfMentionBackground: colors.primary,
          currentUserName: currentUserName,
        ),
        key: const ValueKey('message-content'),
      );
    }

    // Non-system messages: render as Markdown.
    // When searching, fall back to plain text with highlight
    // (Markdown + highlight is not trivially composable).
    if (highlightQuery.isNotEmpty) {
      return Text.rich(
        buildMentionAwareSpan(
          text: message.content,
          baseStyle: effectiveBaseStyle,
          mentionColor: colors.primary,
          mentionBackground: colors.primary.withValues(alpha: 0.1),
          selfMentionColor: colors.primaryForeground,
          selfMentionBackground: colors.primary,
          currentUserName: currentUserName,
          highlightQuery: highlightQuery,
          highlightColor: highlightColor ?? colors.primaryLight,
        ),
        key: const ValueKey('message-content'),
      );
    }

    return MarkdownMessageBody(
      key: const ValueKey('message-content'),
      content: message.content,
      kind: kind,
      baseStyle: effectiveBaseStyle,
      onLinkTap: onLinkTap,
      currentUserName: currentUserName,
    );
  }
}
