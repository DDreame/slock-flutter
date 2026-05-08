import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/markdown_message_body.dart';
import 'package:slock_app/features/conversation/presentation/widgets/mention_syntax.dart';
import 'package:slock_app/features/link_preview/application/link_preview_store.dart';
import 'package:slock_app/features/link_preview/data/link_preview_service.dart';
import 'package:slock_app/features/link_preview/presentation/widgets/link_preview_card.dart';

/// Public widget that renders message content, routing between
/// Markdown rendering for non-system messages and plain italic
/// text for system messages.
///
/// This widget is the integration point between the conversation
/// detail page and the Markdown rendering pipeline.
///
/// When a non-system message contains a URL, a [LinkPreviewCard] is
/// rendered below the message text (first URL only).
class MessageContentWidget extends ConsumerStatefulWidget {
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
  ConsumerState<MessageContentWidget> createState() =>
      _MessageContentWidgetState();
}

class _MessageContentWidgetState extends ConsumerState<MessageContentWidget> {
  String? _detectedUrl;

  @override
  void initState() {
    super.initState();
    _detectAndFetchUrl();
  }

  @override
  void didUpdateWidget(MessageContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.content != widget.message.content) {
      _detectAndFetchUrl();
    }
  }

  void _detectAndFetchUrl() {
    if (widget.isSystem) {
      _detectedUrl = null;
      return;
    }
    final url = extractFirstUrl(widget.message.content);
    _detectedUrl = url;
    if (url != null) {
      // Trigger async fetch — will update the cache provider.
      Future.microtask(
          () => ref.read(linkPreviewCacheProvider.notifier).fetch(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    final effectiveBaseStyle = widget.baseStyle ??
        (widget.isSystem
            ? AppTypography.body.copyWith(
                color: colors.textSecondary,
                fontStyle: FontStyle.italic,
              )
            : AppTypography.body.copyWith(color: colors.text));

    // System messages: plain text, no Markdown rendering.
    if (widget.isSystem) {
      if (widget.highlightQuery.isNotEmpty) {
        return Text.rich(
          buildMentionAwareSpan(
            text: widget.message.content,
            baseStyle: effectiveBaseStyle,
            mentionColor: colors.primary,
            mentionBackground: colors.primary.withValues(alpha: 0.1),
            selfMentionColor: colors.primaryForeground,
            selfMentionBackground: colors.primary,
            currentUserName: widget.currentUserName,
            highlightQuery: widget.highlightQuery,
            highlightColor: colors.primaryLight,
          ),
          key: const ValueKey('message-content'),
        );
      }
      return Text.rich(
        buildMentionAwareSpan(
          text: widget.message.content,
          baseStyle: effectiveBaseStyle,
          mentionColor: colors.primary,
          mentionBackground: colors.primary.withValues(alpha: 0.1),
          selfMentionColor: colors.primaryForeground,
          selfMentionBackground: colors.primary,
          currentUserName: widget.currentUserName,
        ),
        key: const ValueKey('message-content'),
      );
    }

    // Non-system messages: render as Markdown.
    // When searching, fall back to plain text with highlight
    // (Markdown + highlight is not trivially composable).
    Widget textWidget;
    if (widget.highlightQuery.isNotEmpty) {
      textWidget = Text.rich(
        buildMentionAwareSpan(
          text: widget.message.content,
          baseStyle: effectiveBaseStyle,
          mentionColor: colors.primary,
          mentionBackground: colors.primary.withValues(alpha: 0.1),
          selfMentionColor: colors.primaryForeground,
          selfMentionBackground: colors.primary,
          currentUserName: widget.currentUserName,
          highlightQuery: widget.highlightQuery,
          highlightColor: colors.primaryLight,
        ),
        key: const ValueKey('message-content'),
      );
    } else {
      textWidget = MarkdownMessageBody(
        key: const ValueKey('message-content'),
        content: widget.message.content,
        kind: widget.kind,
        baseStyle: effectiveBaseStyle,
        onLinkTap: widget.onLinkTap,
        currentUserName: widget.currentUserName,
      );
    }

    // Append link preview card if a URL was detected.
    if (_detectedUrl == null) return textWidget;

    final cache = ref.watch(linkPreviewCacheProvider);
    final asyncMeta = cache[_detectedUrl];

    // No data yet or loading — just show the text.
    if (asyncMeta == null || asyncMeta is AsyncLoading) {
      return textWidget;
    }

    // Error or null metadata — no card.
    final metadata = asyncMeta.valueOrNull;
    if (metadata == null || !metadata.isDisplayable) {
      return textWidget;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        textWidget,
        LinkPreviewCard(
          metadata: metadata,
          onTap: widget.onLinkTap != null
              ? () =>
                  widget.onLinkTap!(metadata.title, metadata.url, metadata.url)
              : null,
        ),
      ],
    );
  }
}
