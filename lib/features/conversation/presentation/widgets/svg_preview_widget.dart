import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

/// Inline preview for SVG attachments (INV-ATTACH-1).
///
/// Fetches the SVG content from the attachment URL and renders it inline
/// using [SvgPicture.string]. Constrained to 200×280 to match image
/// preview dimensions. On error, shows a fallback row (INV-ATTACH-2).
class SvgPreviewWidget extends StatefulWidget {
  const SvgPreviewWidget({super.key, required this.attachment});

  final MessageAttachment attachment;

  @override
  State<SvgPreviewWidget> createState() => _SvgPreviewWidgetState();
}

class _SvgPreviewWidgetState extends State<SvgPreviewWidget> {
  String? _svgContent;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSvg();
  }

  Future<void> _fetchSvg() async {
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
      if (content.isEmpty) {
        setState(() {
          _error = 'Empty SVG';
          _loading = false;
        });
        return;
      }
      setState(() {
        _svgContent = content;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load SVG';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _FallbackRow(
        key: ValueKey('svg-fallback-${widget.attachment.name}'),
        attachment: widget.attachment,
        errorHint: _error!,
      );
    }

    if (_loading) {
      return Padding(
        key: ValueKey('svg-loading-${widget.attachment.name}'),
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

    final theme = Theme.of(context);
    return Column(
      key: ValueKey('svg-preview-${widget.attachment.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.attachment.name,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 200,
              maxWidth: 280,
            ),
            child: SvgPicture.string(
              _svgContent!,
              fit: BoxFit.contain,
              placeholderBuilder: (context) => const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 2),
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
