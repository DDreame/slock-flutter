import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_helpers.dart';
import 'package:slock_app/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// PR #869: Empty State Illustrations
//
// Tests that ConversationEmptyView includes:
//   1. A 48px chat_bubble_outline icon
//   2. The title text (conversationEmpty)
//   3. The subtitle text (conversationEmptySubtitle)
// ---------------------------------------------------------------------------

void main() {
  testWidgets(
    'ConversationEmptyView shows icon, title, and subtitle',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: ConversationEmptyView(title: '#general'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Icon present (48px chat bubble outline).
      final iconFinder = find.byIcon(Icons.chat_bubble_outline);
      expect(
        iconFinder,
        findsOneWidget,
        reason: 'Empty state must show chat bubble icon',
      );
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.size, 48);

      // Title text present.
      expect(
        find.text('No messages in #general yet.'),
        findsOneWidget,
        reason: 'Empty state must show title with channel name',
      );

      // Subtitle text present.
      expect(
        find.text('Send the first message to start the conversation.'),
        findsOneWidget,
        reason: 'Empty state must show subtitle',
      );
    },
  );

  testWidgets(
    'ConversationEmptyView shows Chinese subtitle in ZH locale',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: ConversationEmptyView(title: '#general'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chinese subtitle present.
      expect(
        find.text('发送第一条消息来开始对话。'),
        findsOneWidget,
        reason: 'Empty state must show Chinese subtitle in ZH locale',
      );

      // English subtitle absent.
      expect(
        find.text('Send the first message to start the conversation.'),
        findsNothing,
        reason: 'English subtitle must not appear in ZH locale',
      );
    },
  );
}
