import 'package:flutter/material.dart';
import 'package:slock_app/core/utils/time_format.dart';
import 'package:slock_app/features/search/data/search_repository.dart';

class SearchResultItem extends StatelessWidget {
  const SearchResultItem({
    super.key,
    required this.result,
    required this.query,
    required this.onTap,
  });

  final SearchResultMessage result;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = result.message;

    return InkWell(
      key: ValueKey('search-result-${message.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.channelName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '#${result.channelName}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    message.senderLabel,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                Text(
                  formatRelativeTime(message.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            _HighlightedContent(
              content: message.content,
              query: query,
              baseStyle: theme.textTheme.bodyMedium,
              highlightColor: theme.colorScheme.primaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedContent extends StatelessWidget {
  const _HighlightedContent({
    required this.content,
    required this.query,
    required this.baseStyle,
    required this.highlightColor,
  });

  final String content;
  final String query;
  final TextStyle? baseStyle;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(content,
          style: baseStyle, maxLines: 3, overflow: TextOverflow.ellipsis);
    }
    return Text.rich(
      buildHighlightedSpan(content, query, baseStyle, highlightColor),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

TextSpan buildHighlightedSpan(
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
