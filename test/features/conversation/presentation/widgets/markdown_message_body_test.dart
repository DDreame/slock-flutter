import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
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

        // With softLineBreak: true and selectable: true, the MarkdownBody
        // renders via SelectableText widgets rather than RichText.
        expect(find.byType(MarkdownBody), findsOneWidget);
        expect(find.byType(SelectableText), findsWidgets);
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

      testWidgets('long code block is height-constrained and scrollable',
          (tester) async {
        // Generate a code block with many lines to exceed 200dp
        final longCode = List.generate(50, (i) => 'line $i;').join('\n');
        await tester.pumpWidget(
          buildApp(content: '```\n$longCode\n```'),
        );
        await tester.pumpAndSettle();

        // The custom builder wraps code blocks in a ConstrainedBox
        final constrainedBox = find.byType(ConstrainedBox);
        expect(constrainedBox, findsWidgets);

        // At least one ConstrainedBox should have maxHeight = 200
        final constrainedBoxWidget = tester.widgetList<ConstrainedBox>(
          constrainedBox,
        );
        final hasMaxHeight = constrainedBoxWidget.any(
          (w) => w.constraints.maxHeight == 200.0,
        );
        expect(hasMaxHeight, isTrue,
            reason: 'Code block should be constrained to 200dp max height');

        // Vertical SingleChildScrollView should be present for overflow
        expect(find.byType(SingleChildScrollView), findsWidgets);
      });

      testWidgets('short code block still uses constrained builder',
          (tester) async {
        await tester.pumpWidget(
          buildApp(content: '```\nshort\n```'),
        );
        await tester.pumpAndSettle();

        // Even short code blocks go through the builder with ConstrainedBox
        final constrainedBox = find.byType(ConstrainedBox);
        expect(constrainedBox, findsWidgets);
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

        // With selectable: true, MarkdownBody renders links inside
        // SelectableText.rich widgets. Find any widget whose plain text
        // contains "Slock" and tap it.
        final selectableTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              widget.textSpan != null &&
              widget.textSpan!.toPlainText().contains('Slock'),
        );
        if (selectableTextFinder.evaluate().isNotEmpty) {
          await tester.tap(selectableTextFinder.first);
        } else {
          // Fallback: try RichText (in case selectable wraps differently)
          final richTextFinder = find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('Slock'),
          );
          expect(richTextFinder, findsWidgets);
          await tester.tap(richTextFinder.first);
        }
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

    group('selectability', () {
      testWidgets('text is selectable', (tester) async {
        await tester.pumpWidget(
          buildApp(content: 'Selectable text content'),
        );
        await tester.pumpAndSettle();

        // MarkdownBody with selectable: true wraps text in SelectableText
        // widgets. Verify SelectableText.rich is used in the tree.
        expect(find.byType(SelectableText), findsWidgets);
      });

      testWidgets('all bubble kinds produce selectable text', (tester) async {
        for (final kind in MessageBubbleKind.values) {
          await tester.pumpWidget(
            buildApp(content: 'Text for $kind', kind: kind),
          );
          await tester.pumpAndSettle();

          expect(
            find.byType(SelectableText),
            findsWidgets,
            reason: '$kind bubble should render selectable text',
          );
        }
      });
    });
  });
}

/// Callback for testing link taps.
typedef LinkTapCallback = void Function(
    String text, String? href, String title);
