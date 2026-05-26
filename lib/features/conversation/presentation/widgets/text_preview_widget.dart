import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/conversation/presentation/widgets/fetch_preview_widget.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Inline preview for text-based attachments — Markdown or plain text
/// (INV-ATTACH-1).
///
/// When [isMarkdown] is true, renders with [MarkdownBody]. Otherwise
/// renders plain text in a monospace font. Shows at most [_maxPreviewChars]
/// characters; the rest is behind a "Show more" toggle.
/// On error, renders [fallback] (INV-ATTACH-2).
class TextPreviewWidget extends FetchPreviewWidget {
  const TextPreviewWidget({
    super.key,
    required super.attachment,
    required this.isMarkdown,
    super.fallback,
    super.contentFetcher,
  });

  final bool isMarkdown;

  @override
  ConsumerState<TextPreviewWidget> createState() => _TextPreviewWidgetState();
}

class _TextPreviewWidgetState
    extends FetchPreviewWidgetState<TextPreviewWidget> {
  static const _maxPreviewChars = 500;

  String? _content;
  bool _expanded = false;

  @override
  String get diagnosticsTag => 'TextPreview';

  @override
  void onFetchSuccess(String content) {
    setState(() {
      _content = content;
      loading = false;
    });
  }

  @override
  Widget buildContent(BuildContext context) {
    final content = _content ?? '';
    final truncated = content.length > _maxPreviewChars && !_expanded;
    final displayContent =
        truncated ? content.substring(0, _maxPreviewChars) : content;

    final theme = Theme.of(context);
    return Column(
      key: ValueKey('text-preview-${widget.attachment.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.attachment.name,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: widget.isMarkdown
                ? MarkdownBody(
                    data: displayContent,
                    shrinkWrap: true,
                    softLineBreak: true,
                  )
                : Text(
                    displayContent,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontFamilyFallback: const ['Courier'],
                    ),
                  ),
          ),
        ),
        if (truncated)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Semantics(
              button: true,
              child: GestureDetector(
                key: const ValueKey('text-preview-show-more'),
                onTap: () => setState(() => _expanded = true),
                child: Text(
                  context.l10n.textPreviewShowMore,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
