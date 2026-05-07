import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/presentation/widgets/mention_syntax.dart';

void main() {
  group('MentionSyntax', () {
    late md.Document document;

    setUp(() {
      document = md.Document(
        inlineSyntaxes: [MentionSyntax()],
        extensionSet: md.ExtensionSet.none,
      );
    });

    test('parses simple @mention', () {
      final nodes = document.parseInline('@alice');
      expect(nodes.length, 1);
      final element = nodes.first as md.Element;
      expect(element.tag, 'mention');
      expect(element.attributes['name'], 'alice');
      expect(element.textContent, '@alice');
    });

    test('parses @mention with dots and hyphens', () {
      final nodes = document.parseInline('@user.name-123');
      expect(nodes.length, 1);
      final element = nodes.first as md.Element;
      expect(element.attributes['name'], 'user.name-123');
    });

    test('parses @mention in middle of text', () {
      final nodes = document.parseInline('Hello @bob how are you?');
      // Should be: text "Hello ", mention element, text " how are you?"
      expect(nodes.length, 3);
      expect((nodes[1] as md.Element).tag, 'mention');
      expect((nodes[1] as md.Element).attributes['name'], 'bob');
    });

    test('parses multiple @mentions', () {
      final nodes = document.parseInline('@alice and @bob');
      final mentions = nodes.whereType<md.Element>().toList();
      expect(mentions.length, 2);
      expect(mentions[0].attributes['name'], 'alice');
      expect(mentions[1].attributes['name'], 'bob');
    });

    test('does not match bare @ without name', () {
      final nodes = document.parseInline('email@ someone');
      final mentions =
          nodes.whereType<md.Element>().where((e) => e.tag == 'mention');
      expect(mentions, isEmpty);
    });

    test('does not match @mention inside email address', () {
      final nodes = document.parseInline('test@example.com');
      final mentions =
          nodes.whereType<md.Element>().where((e) => e.tag == 'mention');
      expect(mentions, isEmpty);
    });

    test('does not match @mention mid-word after dot', () {
      final nodes = document.parseInline('foo.@bar');
      final mentions =
          nodes.whereType<md.Element>().where((e) => e.tag == 'mention');
      expect(mentions, isEmpty);
    });

    test('matches @mention after punctuation like paren', () {
      final nodes = document.parseInline('(@alice)');
      final mentions =
          nodes.whereType<md.Element>().where((e) => e.tag == 'mention');
      expect(mentions.length, 1);
      expect(mentions.first.attributes['name'], 'alice');
    });

    test('handles @mention at end of text', () {
      final nodes = document.parseInline('Hey @charlie');
      final mentions =
          nodes.whereType<md.Element>().where((e) => e.tag == 'mention');
      expect(mentions.length, 1);
      expect(mentions.first.attributes['name'], 'charlie');
    });
  });

  group('buildMentionAwareSpan', () {
    const baseStyle = TextStyle(color: Colors.black, fontSize: 14);
    const mentionColor = Colors.blue;
    const mentionBg = Color(0x1A0000FF);
    const selfMentionColor = Colors.white;
    const selfMentionBg = Colors.blue;

    test('returns plain text when no mentions', () {
      final span = buildMentionAwareSpan(
        text: 'Hello world',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
      );
      expect(span.text, 'Hello world');
      expect(span.children, isNull);
    });

    test('styles mention differently from surrounding text', () {
      final span = buildMentionAwareSpan(
        text: 'Hello @alice world',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
      );
      expect(span.children, isNotNull);
      expect(span.children!.length, 3);

      final mentionSpan = span.children![1] as TextSpan;
      expect(mentionSpan.text, '@alice');
      expect(mentionSpan.style!.color, mentionColor);
      expect(mentionSpan.style!.fontWeight, FontWeight.w600);
      expect(mentionSpan.style!.backgroundColor, mentionBg);
    });

    test('highlights self-mention with distinct style', () {
      final span = buildMentionAwareSpan(
        text: 'Hey @alice check this',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        currentUserName: 'alice',
      );
      expect(span.children, isNotNull);

      final mentionSpan = span.children![1] as TextSpan;
      expect(mentionSpan.text, '@alice');
      expect(mentionSpan.style!.color, selfMentionColor);
      expect(mentionSpan.style!.backgroundColor, selfMentionBg);
    });

    test('self-mention matching is case-insensitive', () {
      final span = buildMentionAwareSpan(
        text: 'Hello @Alice',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        currentUserName: 'alice',
      );
      final mentionSpan = span.children![1] as TextSpan;
      expect(mentionSpan.style!.color, selfMentionColor);
    });

    test('handles multiple mentions with mixed self/other', () {
      final span = buildMentionAwareSpan(
        text: '@alice mentioned @bob',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        currentUserName: 'alice',
      );
      expect(span.children, isNotNull);

      // @alice = self
      final aliceSpan = span.children![0] as TextSpan;
      expect(aliceSpan.text, '@alice');
      expect(aliceSpan.style!.color, selfMentionColor);

      // @bob = other
      final bobSpan = span.children![2] as TextSpan;
      expect(bobSpan.text, '@bob');
      expect(bobSpan.style!.color, mentionColor);
    });

    test('composes with highlight query', () {
      final span = buildMentionAwareSpan(
        text: 'Hello @alice world',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        highlightQuery: 'Hello',
        highlightColor: Colors.yellow,
      );
      expect(span.children, isNotNull);
      // First segment "Hello " should have highlight within it.
      // The mention "@alice" should be styled as mention.
      final children = span.children!;
      expect(children.length, greaterThan(2));
    });

    test('does not match email addresses as mentions', () {
      final span = buildMentionAwareSpan(
        text: 'Contact test@example.com for help',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
      );
      // Should be plain text, no mention children
      expect(span.text, 'Contact test@example.com for help');
      expect(span.children, isNull);
    });

    test('highlights search query inside mention text', () {
      final span = buildMentionAwareSpan(
        text: 'Hey @alice check',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        highlightQuery: 'alice',
        highlightColor: Colors.yellow,
      );
      expect(span.children, isNotNull);
      // Find the children that form the mention — they should contain
      // a highlighted "alice" portion with backgroundColor = yellow.
      final allSpans = span.children!.cast<TextSpan>();
      final highlightedInMention = allSpans.where((s) =>
          s.text != null &&
          s.text!.contains('alice') &&
          s.style?.backgroundColor == Colors.yellow);
      expect(highlightedInMention, isNotEmpty,
          reason: 'Search query inside mention should be highlighted');
    });
  });

  group('MentionBuilder widget rendering', () {
    Widget buildApp({
      required String content,
      String? currentUserName,
    }) {
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final colors = Theme.of(context).extension<AppColors>();
              return Text.rich(
                buildMentionAwareSpan(
                  text: content,
                  baseStyle: const TextStyle(color: Colors.black),
                  mentionColor: colors!.primary,
                  mentionBackground: colors.primary.withValues(alpha: 0.1),
                  selfMentionColor: colors.primaryForeground,
                  selfMentionBackground: colors.primary,
                  currentUserName: currentUserName,
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('renders @mention text in message', (tester) async {
      await tester.pumpWidget(buildApp(content: 'Hey @alice check this'));
      await tester.pumpAndSettle();

      expect(find.textContaining('@alice'), findsOneWidget);
    });

    testWidgets('renders self-mention with different style', (tester) async {
      await tester.pumpWidget(buildApp(
        content: 'Hey @alice',
        currentUserName: 'alice',
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('@alice'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final colors = Theme.of(context).extension<AppColors>()!;
              return Text.rich(
                buildMentionAwareSpan(
                  text: 'Hello @bob',
                  baseStyle: TextStyle(color: colors.text),
                  mentionColor: colors.primary,
                  mentionBackground: colors.primary.withValues(alpha: 0.1),
                  selfMentionColor: colors.primaryForeground,
                  selfMentionBackground: colors.primary,
                ),
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('@bob'), findsOneWidget);
    });
  });
}
