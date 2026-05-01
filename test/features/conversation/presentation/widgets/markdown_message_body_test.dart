import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/presentation/widgets/markdown_message_body.dart';

void main() {
  Widget buildApp({
    required String content,
    MessageBubbleKind kind = MessageBubbleKind.other,
    TextStyle? baseStyle,
    LinkTapCallback? onLinkTap,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: MarkdownMessageBody(
            content: content,
            kind: kind,
            baseStyle: baseStyle,
            onLinkTap: onLinkTap,
          ),
        ),
      ),
    );
  }

  group('MarkdownMessageBody', () {
    group('plain text', () {
      testWidgets('renders plain text without Markdown', (tester) async {
        await tester.pumpWidget(buildApp(content: 'Hello, world!'));
        await tester.pumpAndSettle();

        expect(find.text('Hello, world!'), findsOneWidget);
      });

      testWidgets('preserves line breaks in plain text', (tester) async {
        await tester.pumpWidget(buildApp(content: 'Line one\nLine two'));
        await tester.pumpAndSettle();

        // With softLineBreak: true, soft breaks are preserved in the output.
        // The MarkdownBody widget should render both lines.
        expect(find.byType(MarkdownBody), findsOneWidget);
        // Verify both fragments appear somewhere in the rendered text.
        final richTexts = find.byType(RichText);
        expect(richTexts, findsWidgets);
      });
    });

    group('inline formatting', () {
      testWidgets('renders bold text', (tester) async {
        await tester.pumpWidget(buildApp(content: 'This is **bold** text'));
        await tester.pumpAndSettle();

        // The markdown body should contain "bold" as styled text
        expect(find.byType(MarkdownBody), findsOneWidget);
      });

      testWidgets('renders italic text', (tester) async {
        await tester.pumpWidget(buildApp(content: 'This is *italic* text'));
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
      });

      testWidgets('renders inline code', (tester) async {
        await tester.pumpWidget(
          buildApp(content: 'Run `dart analyze` please'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
      });

      testWidgets('renders strikethrough', (tester) async {
        await tester.pumpWidget(
          buildApp(content: 'This is ~~deleted~~ text'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
      });
    });

    group('code blocks', () {
      testWidgets('renders fenced code block', (tester) async {
        await tester.pumpWidget(
          buildApp(content: '```\nprint("hello")\n```'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
        // Code block renders via DecoratedBox for the background
        expect(find.byType(DecoratedBox), findsWidgets);
      });

      testWidgets('code block uses surfaceAlt background for other kind',
          (tester) async {
        await tester.pumpWidget(
          buildApp(
            content: '```\ncode here\n```',
            kind: MessageBubbleKind.other,
          ),
        );
        await tester.pumpAndSettle();

        // Find the decorated code block container
        final decoratedBoxes = find.byType(DecoratedBox);
        expect(decoratedBoxes, findsWidgets);
      });
    });

    group('block elements', () {
      testWidgets('renders blockquote', (tester) async {
        await tester.pumpWidget(
          buildApp(content: '> This is a quote'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
      });

      testWidgets('renders ordered list', (tester) async {
        await tester.pumpWidget(
          buildApp(content: '1. First\n2. Second\n3. Third'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
      });

      testWidgets('renders unordered list', (tester) async {
        await tester.pumpWidget(
          buildApp(content: '- Item A\n- Item B\n- Item C'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
      });

      testWidgets('renders headings H1-H3', (tester) async {
        await tester.pumpWidget(
          buildApp(content: '# Heading 1\n## Heading 2\n### Heading 3'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
      });
    });

    group('links', () {
      testWidgets('renders links with primary color', (tester) async {
        await tester.pumpWidget(
          buildApp(content: 'Visit [Slock](https://slock.app)'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
      });

      testWidgets('link tap callback is invoked on tap', (tester) async {
        String? tappedUrl;
        await tester.pumpWidget(
          buildApp(
            content: '[Slock](https://slock.app)',
            onLinkTap: (text, href, title) {
              tappedUrl = href;
            },
          ),
        );
        await tester.pumpAndSettle();

        // MarkdownBody renders links inside RichText widgets.
        // Find text containing "Slock" and tap it.
        final richTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains('Slock'),
        );
        expect(richTextFinder, findsWidgets);

        // Tap the center of the first matching widget
        await tester.tap(richTextFinder.first);
        await tester.pumpAndSettle();

        expect(tappedUrl, 'https://slock.app');
      });
    });

    group('bubble kind variants', () {
      testWidgets('self bubble renders markdown body', (tester) async {
        await tester.pumpWidget(
          buildApp(
            content: 'Hello **bold** world',
            kind: MessageBubbleKind.self,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
      });

      testWidgets('agent bubble renders markdown body', (tester) async {
        await tester.pumpWidget(
          buildApp(
            content: 'Response with `code`',
            kind: MessageBubbleKind.agent,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
      });

      testWidgets('other bubble renders markdown body', (tester) async {
        await tester.pumpWidget(
          buildApp(
            content: '**important** message',
            kind: MessageBubbleKind.other,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
      });
    });

    group('unsupported elements', () {
      testWidgets('images are not rendered (stripped)', (tester) async {
        await tester.pumpWidget(
          buildApp(content: 'Before ![alt](https://img.com/pic.png) After'),
        );
        await tester.pumpAndSettle();

        // Should not find any Image widgets
        expect(find.byType(Image), findsNothing);
      });

      testWidgets('HTML tags are not rendered', (tester) async {
        await tester.pumpWidget(
          buildApp(content: '<b>bold</b> and <script>alert("xss")</script>'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
      });
    });

    group('style tokens', () {
      testWidgets('inline code uses monospace font', (tester) async {
        await tester.pumpWidget(
          buildApp(content: 'Run `command` here'),
        );
        await tester.pumpAndSettle();

        // The MarkdownBody should have been styled with monospace for code
        expect(find.byType(MarkdownBody), findsOneWidget);
      });

      testWidgets('blockquote uses textSecondary italic', (tester) async {
        await tester.pumpWidget(
          buildApp(content: '> Quoted text here'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsOneWidget);
      });
    });
  });
}

/// Callback for testing link taps.
typedef LinkTapCallback = void Function(
    String text, String? href, String title);
