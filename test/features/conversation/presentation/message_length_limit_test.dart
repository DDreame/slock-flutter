import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/presentation/utils/message_length_limit.dart';

void main() {
  group('message content length limit', () {
    test('counts grapheme clusters instead of UTF-16 code units', () {
      final emojiDraft = '😀' * maxMessageContentLength;

      expect(emojiDraft.length, maxMessageContentLength * 2);
      expect(messageContentLength(emojiDraft), maxMessageContentLength);
      expect(isMessageContentOverLimit(emojiDraft), isFalse);
      expect(isMessageContentOverLimit('$emojiDraft!'), isTrue);
    });

    test('counts multi-code-point emoji as one visible character', () {
      final thumbsUpWithSkinTone = '👍🏽' * maxMessageContentLength;
      final flag = '🇺🇸' * maxMessageContentLength;
      final family = '👨‍👩‍👧‍👦' * maxMessageContentLength;

      expect(thumbsUpWithSkinTone.runes.length, maxMessageContentLength * 2);
      expect(flag.runes.length, maxMessageContentLength * 2);
      expect(family.runes.length, maxMessageContentLength * 7);
      expect(
          messageContentLength(thumbsUpWithSkinTone), maxMessageContentLength);
      expect(messageContentLength(flag), maxMessageContentLength);
      expect(messageContentLength(family), maxMessageContentLength);
      expect(isMessageContentOverLimit(thumbsUpWithSkinTone), isFalse);
      expect(isMessageContentOverLimit(flag), isFalse);
      expect(isMessageContentOverLimit(family), isFalse);
      expect(isMessageContentOverLimit('${family}a'), isTrue);
    });
  });
}
