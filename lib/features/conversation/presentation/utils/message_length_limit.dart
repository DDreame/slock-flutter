import 'package:characters/characters.dart';

/// Client-side message length limit.
///
/// The current backend accepts message content without an explicit 4000-char
/// validator, but the Flutter UX caps drafts at 4000 user-visible characters.
/// Count Unicode grapheme clusters so multi-code-unit or multi-code-point emoji
/// (for example skin tones, flags, and ZWJ family emoji) match the counter.
const int maxMessageContentLength = 4000;

int messageContentLength(String content) => content.characters.length;

bool isMessageContentOverLimit(String content) {
  return messageContentLength(content) > maxMessageContentLength;
}
