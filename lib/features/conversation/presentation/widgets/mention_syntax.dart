import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';

/// Inline syntax that matches `@username` patterns in message text.
///
/// Matches: `@` followed by one or more word characters (letters, digits,
/// underscores, hyphens, dots). The match is bounded: it must appear at
/// the start of the string or after a whitespace/punctuation character.
///
/// Produces an `md.Element` with tag `mention` containing the full mention
/// text (including the `@` prefix) as text content.
class MentionSyntax extends md.InlineSyntax {
  MentionSyntax() : super(r'@([\w][\w.\-]*)');

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    final start = startMatchPos ?? parser.pos;
    // Mention must be at start of string or preceded by whitespace/punctuation
    // (not a word character or dot, which would indicate email or mid-word).
    if (start > 0) {
      final preceding = parser.source.codeUnitAt(start - 1);
      // Allow if preceded by whitespace or common punctuation
      // Reject if preceded by word char (a-z, A-Z, 0-9, _) or dot
      if (_isWordCharOrDot(preceding)) {
        return false;
      }
    }
    return super.tryMatch(parser, startMatchPos);
  }

  /// Returns true if the code unit is a word character [a-zA-Z0-9_] or dot.
  static bool _isWordCharOrDot(int codeUnit) {
    // 0-9: 48-57, A-Z: 65-90, _: 95, a-z: 97-122, .: 46
    return (codeUnit >= 48 && codeUnit <= 57) ||
        (codeUnit >= 65 && codeUnit <= 90) ||
        codeUnit == 95 ||
        (codeUnit >= 97 && codeUnit <= 122) ||
        codeUnit == 46;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final mentionName = match.group(1)!;
    final element = md.Element.text('mention', '@$mentionName');
    element.attributes['name'] = mentionName;
    parser.addNode(element);
    return true;
  }
}

/// Element builder that renders `mention` elements as styled inline chips.
///
/// When [currentUserName] matches the mentioned name (case-insensitive),
/// the mention is rendered with extra emphasis (background highlight)
/// so the user can easily spot their own mentions.
class MentionBuilder extends MarkdownElementBuilder {
  MentionBuilder({this.currentUserName});

  /// The display name of the current user, for self-mention highlighting.
  final String? currentUserName;

  /// Colors reference — set during visitElementAfterWithContext from context.
  AppColors? _colors;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    _colors ??= Theme.of(context).extension<AppColors>();
    final colors = _colors!;
    final name = element.attributes['name'] ?? '';
    final isSelfMention = currentUserName != null &&
        name.toLowerCase() == currentUserName!.toLowerCase();

    final style =
        (preferredStyle ?? parentStyle ?? AppTypography.body).copyWith(
      color: isSelfMention ? colors.primaryForeground : colors.primary,
      fontWeight: FontWeight.w600,
      backgroundColor: isSelfMention
          ? colors.primary
          : colors.primary.withValues(alpha: 0.1),
    );

    return Text.rich(
      TextSpan(text: '@$name', style: style),
    );
  }
}

/// Compiled mention pattern shared by [buildMentionAwareSpan].
///
/// Matches `@username` at word boundaries (not inside emails).
/// Promoted from a local variable to a module-level constant to avoid
/// per-call [RegExp] allocation on a hot render path.
@visibleForTesting
final mentionSpanRegex = RegExp(r'(?<![\w.])@([\w][\w.\-]*)');

/// Parses message text for @mentions and returns styled [TextSpan] children.
///
/// Used in the search-highlight fallback path where Markdown rendering
/// is bypassed. Mentions are styled distinctly, with self-mentions getting
/// extra background emphasis.
TextSpan buildMentionAwareSpan({
  required String text,
  required TextStyle? baseStyle,
  required Color mentionColor,
  required Color mentionBackground,
  required Color selfMentionColor,
  required Color selfMentionBackground,
  String? currentUserName,
  String highlightQuery = '',
  Color? highlightColor,
}) {
  final matches = mentionSpanRegex.allMatches(text).toList();

  if (matches.isEmpty) {
    // No mentions — fall through to simple highlight or plain text.
    if (highlightQuery.isNotEmpty && highlightColor != null) {
      return _buildHighlightedSpan(
          text, highlightQuery, baseStyle, highlightColor);
    }
    return TextSpan(text: text, style: baseStyle);
  }

  final spans = <InlineSpan>[];
  var lastEnd = 0;

  for (final match in matches) {
    // Text before the mention.
    if (match.start > lastEnd) {
      final before = text.substring(lastEnd, match.start);
      if (highlightQuery.isNotEmpty && highlightColor != null) {
        spans.addAll(
          _buildHighlightedSpan(
                      before, highlightQuery, baseStyle, highlightColor)
                  .children ??
              [TextSpan(text: before, style: baseStyle)],
        );
      } else {
        spans.add(TextSpan(text: before, style: baseStyle));
      }
    }

    // The mention itself.
    final name = match.group(1)!;
    final isSelf = currentUserName != null &&
        name.toLowerCase() == currentUserName.toLowerCase();

    final mentionStyle = (baseStyle ?? const TextStyle()).copyWith(
      color: isSelf ? selfMentionColor : mentionColor,
      fontWeight: FontWeight.w600,
      backgroundColor: isSelf ? selfMentionBackground : mentionBackground,
    );

    // Apply highlight overlay inside the mention when search query matches.
    if (highlightQuery.isNotEmpty && highlightColor != null) {
      final mentionText = '@$name';
      final highlightedMention = _buildHighlightedSpan(
        mentionText,
        highlightQuery,
        mentionStyle,
        highlightColor,
      );
      if (highlightedMention.children != null &&
          highlightedMention.children!.isNotEmpty) {
        spans.addAll(highlightedMention.children!);
      } else {
        spans.add(TextSpan(text: mentionText, style: mentionStyle));
      }
    } else {
      spans.add(TextSpan(text: '@$name', style: mentionStyle));
    }

    lastEnd = match.end;
  }

  // Remaining text after last mention.
  if (lastEnd < text.length) {
    final remaining = text.substring(lastEnd);
    if (highlightQuery.isNotEmpty && highlightColor != null) {
      spans.addAll(
        _buildHighlightedSpan(
                    remaining, highlightQuery, baseStyle, highlightColor)
                .children ??
            [TextSpan(text: remaining, style: baseStyle)],
      );
    } else {
      spans.add(TextSpan(text: remaining, style: baseStyle));
    }
  }

  return TextSpan(children: spans);
}

/// Simple highlighted text span (same as existing `_buildHighlightedSpan`
/// in message_content_widget.dart, duplicated here for composition).
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
