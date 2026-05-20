import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:slock_app/features/conversation/presentation/widgets/fetch_preview_widget.dart';

/// Inline preview for SVG attachments (INV-ATTACH-1).
///
/// Fetches the SVG content from the attachment URL and renders it inline
/// using [SvgPicture.string]. Constrained to 200×280 to match image
/// preview dimensions. On error, renders [fallback] (INV-ATTACH-2).
class SvgPreviewWidget extends FetchPreviewWidget {
  const SvgPreviewWidget({
    super.key,
    required super.attachment,
    super.fallback,
    super.contentFetcher,
  });

  @override
  ConsumerState<SvgPreviewWidget> createState() => _SvgPreviewWidgetState();
}

class _SvgPreviewWidgetState extends FetchPreviewWidgetState<SvgPreviewWidget> {
  String? _svgContent;

  @override
  String get diagnosticsTag => 'SvgPreview';

  @override
  void onFetchSuccess(String content) {
    if (content.isEmpty) {
      setState(() {
        hasError = true;
        loading = false;
      });
      return;
    }
    setState(() {
      _svgContent = content;
      loading = false;
    });
  }

  @override
  Widget buildContent(BuildContext context) {
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
