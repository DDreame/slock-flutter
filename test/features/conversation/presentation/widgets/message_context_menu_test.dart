import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_context_menu.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  ConversationMessageSummary makeMessage({
    String id = 'msg-1',
    String content = 'Hello world',
    String senderType = 'human',
    bool isPinned = false,
    bool isDeleted = false,
  }) {
    return ConversationMessageSummary(
      id: id,
      content: content,
      createdAt: DateTime(2026, 1, 1),
      senderType: senderType,
      messageType: 'message',
      senderName: 'Alice',
      isPinned: isPinned,
      isDeleted: isDeleted,
    );
  }

  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      ),
    );
  }

  group('MessageContextMenu', () {
    testWidgets('renders all non-owner actions for other messages',
        (tester) async {
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: false,
                isSaved: false,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () {},
                onReplyInThread: () {},
                onCreateTask: () {},
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      // Non-owner actions visible.
      expect(find.byKey(const ValueKey('ctx-action-reply')), findsOneWidget);
      expect(find.byKey(const ValueKey('ctx-action-react')), findsOneWidget);
      expect(find.byKey(const ValueKey('ctx-action-copy')), findsOneWidget);
      expect(find.byKey(const ValueKey('ctx-action-save')), findsOneWidget);
      expect(find.byKey(const ValueKey('ctx-action-pin')), findsOneWidget);
      expect(find.byKey(const ValueKey('ctx-action-forward')), findsOneWidget);
      expect(find.byKey(const ValueKey('ctx-action-reply-thread')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('ctx-action-create-task')), findsOneWidget);

      // Owner-only actions hidden.
      expect(find.byKey(const ValueKey('ctx-action-edit')), findsNothing);
      expect(find.byKey(const ValueKey('ctx-action-delete')), findsNothing);
    });

    testWidgets('renders owner actions (edit, delete) for own messages',
        (tester) async {
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: true,
                isSaved: false,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () {},
                onEdit: () {},
                onDelete: () {},
                onReplyInThread: () {},
                onCreateTask: () {},
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ctx-action-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('ctx-action-delete')), findsOneWidget);
    });

    testWidgets('shows "Unsave" when message is already saved', (tester) async {
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: false,
                isSaved: true,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () {},
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(find.text('Unsave message'), findsOneWidget);
    });

    testWidgets('shows "Unpin" when message is already pinned', (tester) async {
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(isPinned: true),
                isOwn: false,
                isSaved: false,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () {},
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(find.text('Unpin message'), findsOneWidget);
    });

    testWidgets('fires onForward when Forward is tapped', (tester) async {
      bool forwarded = false;
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: false,
                isSaved: false,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () => forwarded = true,
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('ctx-action-forward')));
      await tester.pumpAndSettle();

      expect(forwarded, isTrue);
    });

    testWidgets('fires onCopy when Copy is tapped', (tester) async {
      bool copied = false;
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: false,
                isSaved: false,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () => copied = true,
                onSave: () {},
                onPin: () {},
                onForward: () {},
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('ctx-action-copy')));
      await tester.pumpAndSettle();

      expect(copied, isTrue);
    });

    testWidgets('hides thread and task actions when not in channel',
        (tester) async {
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: false,
                isSaved: false,
                isChannel: false,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () {},
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('ctx-action-reply-thread')), findsNothing);
      expect(
          find.byKey(const ValueKey('ctx-action-create-task')), findsNothing);
    });

    testWidgets('shows translate action when onTranslate is provided',
        (tester) async {
      bool translated = false;
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: false,
                isSaved: false,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () {},
                onTranslate: () => translated = true,
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('ctx-action-translate')), findsOneWidget);
      expect(find.text('Translate'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ctx-action-translate')));
      await tester.pumpAndSettle();

      expect(translated, isTrue);
    });

    testWidgets('hides translate action when onTranslate is null',
        (tester) async {
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: false,
                isSaved: false,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () {},
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ctx-action-translate')), findsNothing);
    });

    testWidgets('dismisses after action tap', (tester) async {
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: false,
                isSaved: false,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () {},
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      // Tap copy.
      await tester.tap(find.byKey(const ValueKey('ctx-action-copy')));
      await tester.pumpAndSettle();

      // Bottom sheet should be dismissed.
      expect(find.byKey(const ValueKey('ctx-action-copy')), findsNothing);
    });

    testWidgets('shows copy-markdown action when onCopyMarkdown is provided',
        (tester) async {
      bool copiedMarkdown = false;
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: false,
                isSaved: false,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () {},
                onCopyMarkdown: () => copiedMarkdown = true,
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ctx-action-copy-markdown')),
          findsOneWidget);
      expect(find.text('Copy markdown'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ctx-action-copy-markdown')));
      await tester.pumpAndSettle();

      expect(copiedMarkdown, isTrue);
    });

    testWidgets('hides copy-markdown action when onCopyMarkdown is null',
        (tester) async {
      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showMessageContextMenu(
                context: context,
                message: makeMessage(),
                isOwn: false,
                isSaved: false,
                isChannel: true,
                onReply: () {},
                onReact: () {},
                onCopy: () {},
                onSave: () {},
                onPin: () {},
                onForward: () {},
              );
            },
            child: const Text('Open menu'),
          );
        }),
      ));

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('ctx-action-copy-markdown')), findsNothing);
    });

    testWidgets('copy-markdown renders ZH locale string (load-bearing L10n)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showMessageContextMenu(
                      context: context,
                      message: makeMessage(),
                      isOwn: false,
                      isSaved: false,
                      isChannel: true,
                      onReply: () {},
                      onReact: () {},
                      onCopy: () {},
                      onSave: () {},
                      onPin: () {},
                      onForward: () {},
                      onCopyMarkdown: () {},
                    );
                  },
                  child: const Text('Open menu'),
                );
              }),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      // ZH string must appear.
      expect(find.text('复制 Markdown'), findsOneWidget);
      // English string must NOT appear — reverting to hardcoded breaks this.
      expect(find.text('Copy markdown'), findsNothing);
    });
  });
}
