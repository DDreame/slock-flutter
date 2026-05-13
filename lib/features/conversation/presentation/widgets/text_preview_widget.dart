import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

/// Inline preview for text-based attachments — Markdown or plain text
/// (INV-ATTACH-1).
///
/// When [isMarkdown] is true, renders with [MarkdownBody]. Otherwise
/// renders plain text in a monospace font. Shows at most [_maxPreviewChars]
/// characters; the rest is behind a "Show more" toggle.
/// On error, shows a fallback row (INV-ATTACH-2).
class TextPreviewWidget extends StatefulWidget {
  const TextPreviewWidget({
    super.key,
    required this.attachment,
    required this.isMarkdown,
  });

  final MessageAttachment attachment;
  final bool isMarkdown;

  @override
  State<TextPreviewWidget> createState() => _TextPreviewWidgetState();
}

class _TextPreviewWidgetState extends State<TextPreviewWidget> {
  static const _maxPreviewChars = 500;

  String? _content;
  bool _loading = true;
  String? _error;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    final url = widget.attachment.url;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _error = 'No download URL');
      return;
    }
    try {
      final response = await Dio().get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      if (!mounted) return;
      final content = response.data ?? '';
      setState(() {
        _content = content;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load content';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _FallbackRow(
        key: ValueKey('text-fallback-${widget.attachment.name}'),
        attachment: widget.attachment,
        errorHint: _error!,
      );
    }

    if (_loading) {
      return Padding(
        key: ValueKey('text-loading-${widget.attachment.name}'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              widget.attachment.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

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
            child: GestureDetector(
              key: const ValueKey('text-preview-show-more'),
              onTap: () => setState(() => _expanded = true),
              child: Text(
                'Show more',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Minimal fallback row shown when preview fails (INV-ATTACH-2).
class _FallbackRow extends StatelessWidget {
  const _FallbackRow({
    super.key,
    required this.attachment,
    required this.errorHint,
  });

  final MessageAttachment attachment;
  final String errorHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.attach_file,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            attachment.name,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          errorHint,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}
