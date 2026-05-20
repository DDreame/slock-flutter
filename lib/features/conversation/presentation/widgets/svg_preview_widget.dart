import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

/// Signature for the content-fetch callback.
typedef ContentFetcher = Future<String> Function(String url);

Future<String> _defaultFetcher(String url) async {
  final response = await Dio().get<String>(
    url,
    options: Options(responseType: ResponseType.plain),
  );
  return response.data ?? '';
}

/// Inline preview for SVG attachments (INV-ATTACH-1).
///
/// Fetches the SVG content from the attachment URL and renders it inline
/// using [SvgPicture.string]. Constrained to 200×280 to match image
/// preview dimensions. On error, renders [fallback] (INV-ATTACH-2).
class SvgPreviewWidget extends ConsumerStatefulWidget {
  const SvgPreviewWidget({
    super.key,
    required this.attachment,
    this.fallback,
    this.contentFetcher,
  });

  final MessageAttachment attachment;

  /// Widget to render on failure. When provided from the attachment router,
  /// this is `_GenericFileAttachmentRow` which preserves file-open behavior.
  final Widget? fallback;

  /// Injectable content fetcher for testing.
  final ContentFetcher? contentFetcher;

  @override
  ConsumerState<SvgPreviewWidget> createState() => _SvgPreviewWidgetState();
}

class _SvgPreviewWidgetState extends ConsumerState<SvgPreviewWidget> {
  String? _svgContent;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetchSvg();
  }

  Future<void> _fetchSvg() async {
    final url = widget.attachment.url;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _error = true);
      return;
    }
    try {
      final fetcher = widget.contentFetcher ?? _defaultFetcher;
      final content = await fetcher(url);
      if (!mounted) return;
      if (content.isEmpty) {
        setState(() {
          _error = true;
          _loading = false;
        });
        return;
      }
      setState(() {
        _svgContent = content;
        _loading = false;
      });
    } on Exception catch (e) {
      ref.read(diagnosticsCollectorProvider).error(
            'SvgPreview',
            'Fetch failed for ${widget.attachment.name}: $e',
          );
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return widget.fallback ??
          _DefaultFallback(
            key: ValueKey('svg-fallback-${widget.attachment.name}'),
            name: widget.attachment.name,
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

/// Simple fallback used when no [SvgPreviewWidget.fallback] is provided.
class _DefaultFallback extends StatelessWidget {
  const _DefaultFallback({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.attach_file,
            size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(
          child: Text(name,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
