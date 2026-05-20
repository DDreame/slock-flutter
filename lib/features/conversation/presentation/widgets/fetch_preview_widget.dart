import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

// ---------------------------------------------------------------------------
// #647: FetchPreviewWidget — shared base class for fetch-based previews
//
// Eliminates duplicated fetch lifecycle across csv/svg/text_preview_widget.
// Provides: URL validation, content fetching, mounted guards, error logging,
// standard loading/error/success build dispatch.
// ---------------------------------------------------------------------------

/// Signature for the content-fetch callback. Tests inject a fake; production
/// uses the default [defaultContentFetcher] which goes through [Dio].
typedef ContentFetcher = Future<String> Function(String url);

/// Default fetcher using Dio for plain-text responses.
Future<String> defaultContentFetcher(String url) async {
  final response = await Dio().get<String>(
    url,
    options: Options(responseType: ResponseType.plain),
  );
  return response.data ?? '';
}

/// Abstract base widget for preview widgets that fetch content from a URL.
///
/// Provides common fields: [attachment], [fallback], [contentFetcher].
/// Subclasses add format-specific fields (e.g. [isMarkdown] on text preview).
abstract class FetchPreviewWidget extends ConsumerStatefulWidget {
  const FetchPreviewWidget({
    super.key,
    required this.attachment,
    this.fallback,
    this.contentFetcher,
  });

  /// The attachment metadata (name, type, url).
  final MessageAttachment attachment;

  /// Widget to render on failure. When provided from the attachment router,
  /// this is `_GenericFileAttachmentRow` which preserves file-open behavior.
  final Widget? fallback;

  /// Injectable content fetcher for testing.
  final ContentFetcher? contentFetcher;
}

/// Shared state for [FetchPreviewWidget] subclasses.
///
/// Handles the fetch lifecycle:
/// 1. [initState] → validate URL → fetch content
/// 2. On success → [onFetchSuccess] (subclass stores parsed data)
/// 3. On error → logs via diagnostics + shows [fallback] / default
/// 4. All [setState] calls are guarded by [mounted]
///
/// Subclasses implement:
/// - [diagnosticsTag] — tag for error logging (e.g. 'CsvPreview')
/// - [onFetchSuccess] — process & store fetched content, call setState
/// - [buildContent] — render the success state
abstract class FetchPreviewWidgetState<T extends FetchPreviewWidget>
    extends ConsumerState<T> {
  /// Whether the widget is still loading content.
  bool loading = true;

  /// Whether a fetch error occurred.
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final url = widget.attachment.url;
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() {
          hasError = true;
          loading = false;
        });
      }
      return;
    }
    try {
      final fetcher = widget.contentFetcher ?? defaultContentFetcher;
      final content = await fetcher(url);
      if (!mounted) return;
      onFetchSuccess(content);
    } on Exception catch (e) {
      if (!mounted) return;
      ref.read(diagnosticsCollectorProvider).error(
            diagnosticsTag,
            'Fetch failed for ${widget.attachment.name}: $e',
          );
      if (!mounted) return;
      setState(() {
        hasError = true;
        loading = false;
      });
    }
  }

  /// Tag for diagnostic error logging (e.g. 'CsvPreview', 'SvgPreview').
  String get diagnosticsTag;

  /// Called with fetched content on success. Subclass must call [setState]
  /// to store the parsed result and set [loading] to false.
  ///
  /// May also set [hasError] if the content is invalid (e.g. empty SVG).
  void onFetchSuccess(String content);

  /// Build the content view for the success state.
  Widget buildContent(BuildContext context);

  /// Build the loading state. Override for custom loading UI.
  Widget buildLoading(BuildContext context) {
    return Padding(
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

  /// Build the error state. Override for custom error UI.
  Widget buildError(BuildContext context) {
    return widget.fallback ??
        DefaultPreviewFallback(name: widget.attachment.name);
  }

  @override
  Widget build(BuildContext context) {
    if (hasError) return buildError(context);
    if (loading) return buildLoading(context);
    return buildContent(context);
  }
}

/// Simple fallback widget shown when fetch fails and no custom [fallback]
/// is provided. Displays a file icon and the attachment name.
class DefaultPreviewFallback extends StatelessWidget {
  const DefaultPreviewFallback({super.key, required this.name});

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
