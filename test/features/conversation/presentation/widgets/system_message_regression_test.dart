import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_content_widget.dart';

void main() {
  group('System message regression', () {
    testWidgets('system messages render as plain italic Text, not Markdown',
        (tester) async {
      final message = ConversationMessageSummary(
        id: 'sys-1',
        content: '**bold** and `code` should NOT render as Markdown',
        createdAt: DateTime.now(),
        senderType: 'system',
        messageType: 'system',
        senderId: null,
        senderName: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MessageContentWidget(
                message: message,
                isSystem: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should NOT find a MarkdownBody — system messages stay as plain text
      expect(find.byType(MarkdownBody), findsNothing);

      // The raw markdown syntax should be visible as-is
      expect(
        find.text(
          '**bold** and `code` should NOT render as Markdown',
        ),
        findsOneWidget,
      );
    });

    testWidgets('non-system messages DO render Markdown', (tester) async {
      final message = ConversationMessageSummary(
        id: 'msg-1',
        content: '**bold** text here',
        createdAt: DateTime.now(),
        senderType: 'human',
        messageType: 'message',
        senderId: 'user-1',
        senderName: 'Alice',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MessageContentWidget(
                message: message,
                isSystem: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should find a MarkdownBody for non-system messages
      expect(find.byType(MarkdownBody), findsOneWidget);
    });
  });
}
