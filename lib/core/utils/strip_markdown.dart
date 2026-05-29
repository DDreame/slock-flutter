/// Converts a markdown-formatted string to plain text by stripping
/// formatting syntax while preserving the readable content.
///
/// Handles: bold, italic, strikethrough, inline code, code fences,
/// links, images, headings, blockquotes, and list markers.
/// Preserves @mentions and #channel refs as-is (not markdown syntax).
String stripMarkdown(String source) {
  var result = source;

  // Code fences (```lang\n...\n```) — remove fences, keep content.
  result = result.replaceAllMapped(
    RegExp(r'```[^\n]*\n([\s\S]*?)```'),
    (m) => m.group(1)?.trimRight() ?? '',
  );

  // Images ![alt](url) → alt
  result = result.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
    (m) => m.group(1) ?? '',
  );

  // Links [text](url) → text
  result = result.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (m) => m.group(1) ?? '',
  );

  // Bold+italic ***text*** or ___text___
  result = result.replaceAllMapped(
    RegExp(r'(\*{3}|_{3})(.+?)\1'),
    (m) => m.group(2) ?? '',
  );

  // Bold **text** or __text__
  result = result.replaceAllMapped(
    RegExp(r'(\*{2}|_{2})(.+?)\1'),
    (m) => m.group(2) ?? '',
  );

  // Italic *text* or _text_ (only when not preceded/followed by word char
  // to avoid stripping e.g. file_names_with_underscores mid-word).
  result = result.replaceAllMapped(
    RegExp(r'(?<!\w)([*_])(.+?)\1(?!\w)'),
    (m) => m.group(2) ?? '',
  );

  // Strikethrough ~~text~~
  result = result.replaceAllMapped(
    RegExp(r'~~(.+?)~~'),
    (m) => m.group(1) ?? '',
  );

  // Inline code `text`
  result = result.replaceAllMapped(
    RegExp(r'`([^`]+)`'),
    (m) => m.group(1) ?? '',
  );

  // Headings # ... (at start of line)
  result = result.replaceAllMapped(
    RegExp(r'^#{1,6}\s+', multiLine: true),
    (_) => '',
  );

  // Blockquotes > ... (at start of line)
  result = result.replaceAllMapped(
    RegExp(r'^>\s?', multiLine: true),
    (_) => '',
  );

  // Unordered list markers (- or * or +) at start of line
  result = result.replaceAllMapped(
    RegExp(r'^[\-\*\+]\s+', multiLine: true),
    (_) => '',
  );

  // Ordered list markers (1. 2. etc.) at start of line
  result = result.replaceAllMapped(
    RegExp(r'^\d+\.\s+', multiLine: true),
    (_) => '',
  );

  return result;
}
