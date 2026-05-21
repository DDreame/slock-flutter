import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  group('conversation hardcoded string extraction', () {
    test('high-visibility conversation keys resolve in supported locales', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final zh = lookupAppLocalizations(const Locale('zh'));
      final es = lookupAppLocalizations(const Locale('es'));

      expect(en.conversationComposerHint, 'Write a message');
      expect(en.conversationContextReply, 'Reply');
      expect(en.conversationContextCopyText, 'Copy text');
      expect(en.conversationDeleteDialogTitle, 'Delete message?');
      expect(en.conversationOpenLinkContent('mailto:test@example.com'),
          'Open mailto:test@example.com?');
      expect(en.conversationSelectionSelected(2), '2 selected');
      expect(en.conversationMessageActionsSemantics, 'Message actions');
      expect(en.conversationComposerAttachTooltip, 'Attach file');
      expect(en.conversationComposerCameraUnavailable,
          'Camera unavailable. Please check permissions.');
      expect(en.conversationReactWithEmojiTitle, 'React with emoji');
      expect(en.conversationReactWithEmojiSemantics('👍'), 'React with 👍');
      expect(en.conversationReactionUpdateFailedFallback,
          'Failed to update reaction.');

      expect(zh.conversationComposerHint, isNot(en.conversationComposerHint));
      expect(zh.conversationContextDeleteMessage,
          isNot(en.conversationContextDeleteMessage));
      expect(zh.conversationOpenLinkContent('mailto:test@example.com'),
          contains('mailto:test@example.com'));
      expect(zh.conversationReactWithEmojiTitle,
          isNot(en.conversationReactWithEmojiTitle));
      expect(zh.conversationReactWithEmojiSemantics('👍'), contains('👍'));
      expect(zh.conversationComposerCameraUnavailable,
          isNot(en.conversationComposerCameraUnavailable));

      expect(es.conversationComposerHint, isNot(en.conversationComposerHint));
      expect(es.conversationContextDeleteMessage,
          isNot(en.conversationContextDeleteMessage));
      expect(es.conversationOpenLinkContent('mailto:test@example.com'),
          contains('mailto:test@example.com'));
      expect(es.conversationReactWithEmojiTitle,
          isNot(en.conversationReactWithEmojiTitle));
      expect(es.conversationReactWithEmojiSemantics('👍'), contains('👍'));
      expect(es.conversationComposerCameraUnavailable,
          isNot(en.conversationComposerCameraUnavailable));
    });
  });
}
