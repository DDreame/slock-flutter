import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/markdown_message_body.dart';

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
  });

  final ConversationMessageSummary message;
  final bool isSystem;
  final MessageBubbleKind kind;
  final String highlightQuery;
  final TextStyle? baseStyle;
  final Color? highlightColor;
  final void Function(String text, String? href, String title)? onLinkTap;

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
          _buildHighlightedSpan(
            message.content,
            highlightQuery,
            effectiveBaseStyle,
            highlightColor ?? colors.primaryLight,
          ),
          key: const ValueKey('message-content'),
        );
      }
      return Text(
        message.content,
        key: const ValueKey('message-content'),
        style: effectiveBaseStyle,
      );
    }

    // Non-system messages: render as Markdown.
    // When searching, fall back to plain text with highlight
    // (Markdown + highlight is not trivially composable).
    if (highlightQuery.isNotEmpty) {
      return Text.rich(
        _buildHighlightedSpan(
          message.content,
          highlightQuery,
          effectiveBaseStyle,
          highlightColor ?? colors.primaryLight,
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
    );
  }
}

TextSpan _buildHighlightedSpan(
  String text,
  String query,
  TextStyle? baseStyle,
  Color highlightColor,
) {
  if (query.isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }

  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final spans = <InlineSpan>[];
  var lastEnd = 0;

  var index = lowerText.indexOf(lowerQuery);
  while (index != -1) {
    if (index > lastEnd) {
      spans.add(
          TextSpan(text: text.substring(lastEnd, index), style: baseStyle));
    }
    spans.add(TextSpan(
      text: text.substring(index, index + query.length),
      style: (baseStyle ?? const TextStyle()).copyWith(
        backgroundColor: highlightColor,
        fontWeight: FontWeight.bold,
      ),
    ));
    lastEnd = index + query.length;
    index = lowerText.indexOf(lowerQuery, lastEnd);
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
  }

  if (spans.isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }
  return TextSpan(children: spans);
}
