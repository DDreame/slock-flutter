import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:slock_app/features/conversation/presentation/widgets/inline_ref_syntax.dart';

void main() {
  group('ChannelRefSyntax', () {
    late md.Document document;

    setUp(() {
      document = md.Document(
        inlineSyntaxes: [ChannelRefSyntax()],
        extensionSet: md.ExtensionSet.none,
      );
    });

    test('parses simple #channel', () {
      final nodes = document.parseInline('#general');
      expect(nodes.length, 1);
      final element = nodes.first as md.Element;
      expect(element.tag, 'channel_ref');
      expect(element.attributes['name'], 'general');
      expect(element.textContent, '#general');
    });

    test('parses #channel with hyphens', () {
      final nodes = document.parseInline('#my-channel');
      expect(nodes.length, 1);
      final element = nodes.first as md.Element;
      expect(element.attributes['name'], 'my-channel');
    });

    test('parses #channel with dots and underscores', () {
      final nodes = document.parseInline('#dev.ops_infra');
      expect(nodes.length, 1);
      final element = nodes.first as md.Element;
      expect(element.attributes['name'], 'dev.ops_infra');
    });

    test('parses #channel in middle of text', () {
      final nodes = document.parseInline('Check out #general for updates');
      expect(nodes.length, 3);
      expect((nodes[1] as md.Element).tag, 'channel_ref');
      expect((nodes[1] as md.Element).attributes['name'], 'general');
    });

    test('parses multiple #channel refs', () {
      final nodes = document.parseInline('#general and #random');
      final refs = nodes.whereType<md.Element>().toList();
      expect(refs.length, 2);
      expect(refs[0].attributes['name'], 'general');
      expect(refs[1].attributes['name'], 'random');
    });

    test('does not match # inside a word (preceded by word char)', () {
      final nodes = document.parseInline('issue#42');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'channel_ref');
      expect(refs, isEmpty);
    });

    test('does not match # preceded by dot', () {
      final nodes = document.parseInline('foo.#bar');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'channel_ref');
      expect(refs, isEmpty);
    });

    test('matches #channel after punctuation like paren', () {
      final nodes = document.parseInline('(#general)');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'channel_ref');
      expect(refs.length, 1);
      expect(refs.first.attributes['name'], 'general');
    });

    test('matches #channel at start of text', () {
      final nodes = document.parseInline('#general is active');
      expect(nodes.first, isA<md.Element>());
      expect((nodes.first as md.Element).attributes['name'], 'general');
    });
  });

  group('TaskRefSyntax', () {
    late md.Document document;

    setUp(() {
      document = md.Document(
        inlineSyntaxes: [TaskRefSyntax()],
        extensionSet: md.ExtensionSet.none,
      );
    });

    test('parses "task #42"', () {
      final nodes = document.parseInline('task #42');
      expect(nodes.length, 1);
      final element = nodes.first as md.Element;
      expect(element.tag, 'task_ref');
      expect(element.attributes['number'], '42');
    });

    test('parses "Task #1" (case-insensitive)', () {
      final nodes = document.parseInline('Task #1');
      expect(nodes.length, 1);
      final element = nodes.first as md.Element;
      expect(element.tag, 'task_ref');
      expect(element.attributes['number'], '1');
    });

    test('parses "TASK #99" (all caps)', () {
      final nodes = document.parseInline('TASK #99');
      expect(nodes.length, 1);
      final element = nodes.first as md.Element;
      expect(element.attributes['number'], '99');
    });

    test('parses task ref in middle of text', () {
      final nodes = document.parseInline('Please check task #5 for details');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'task_ref');
      expect(refs.length, 1);
      expect(refs.first.attributes['number'], '5');
    });

    test('parses multiple task refs', () {
      final nodes = document.parseInline('task #1 and task #2');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'task_ref');
      expect(refs.length, 2);
      expect(refs.first.attributes['number'], '1');
      expect(refs.last.attributes['number'], '2');
    });

    test('does not match "subtask #3" (preceded by word char)', () {
      final nodes = document.parseInline('subtask #3');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'task_ref');
      expect(refs, isEmpty);
    });

    test('matches task ref after punctuation', () {
      final nodes = document.parseInline('(task #7)');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'task_ref');
      expect(refs.length, 1);
      expect(refs.first.attributes['number'], '7');
    });

    test('matches task ref at start of text', () {
      final nodes = document.parseInline('task #10 is done');
      expect(nodes.first, isA<md.Element>());
      expect((nodes.first as md.Element).attributes['number'], '10');
    });

    test('handles "task#42" (no space)', () {
      final nodes = document.parseInline('task#42');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'task_ref');
      expect(refs.length, 1);
      expect(refs.first.attributes['number'], '42');
    });

    test('does not match "task #3x" (trailing word char)', () {
      final nodes = document.parseInline('task #3x');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'task_ref');
      expect(refs, isEmpty,
          reason: 'Removing trailing boundary guard → test RED');
    });

    test('does not match "task #3-foo" (trailing hyphen + word)', () {
      final nodes = document.parseInline('task #3-foo');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'task_ref');
      expect(refs, isEmpty,
          reason: 'Removing trailing boundary guard → test RED');
    });

    test('matches "task #3." (trailing period is valid boundary)', () {
      final nodes = document.parseInline('task #3.');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'task_ref');
      expect(refs.length, 1);
      expect(refs.first.attributes['number'], '3');
    });

    test('matches "task #3," (trailing comma is valid boundary)', () {
      final nodes = document.parseInline('task #3,');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'task_ref');
      expect(refs.length, 1);
      expect(refs.first.attributes['number'], '3');
    });
  });

  group('buildInlineRefAwareSpan', () {
    const baseStyle = TextStyle(color: Colors.black, fontSize: 14);
    const mentionColor = Colors.blue;
    const mentionBg = Color(0x1A0000FF);
    const selfMentionColor = Colors.white;
    const selfMentionBg = Colors.blue;
    const refColor = Colors.indigo;
    const refBg = Color(0x1A3F51B5);

    test('returns plain text when no inline refs', () {
      final span = buildInlineRefAwareSpan(
        text: 'Hello world',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
      );
      expect(span.text, 'Hello world');
      expect(span.children, isNull);
    });

    test('styles @mention with mention colors', () {
      final span = buildInlineRefAwareSpan(
        text: 'Hello @alice world',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
      );
      expect(span.children, isNotNull);
      expect(span.children!.length, 3);

      final mentionSpan = span.children![1] as TextSpan;
      expect(mentionSpan.text, '@alice');
      expect(mentionSpan.style!.color, mentionColor);
      expect(mentionSpan.style!.fontWeight, FontWeight.w600);
    });

    test('styles #channel with ref colors', () {
      final span = buildInlineRefAwareSpan(
        text: 'Check #general now',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
      );
      expect(span.children, isNotNull);
      expect(span.children!.length, 3);

      final refSpan = span.children![1] as TextSpan;
      expect(refSpan.text, '#general');
      expect(refSpan.style!.color, refColor);
      expect(refSpan.style!.backgroundColor, refBg);
      expect(refSpan.style!.fontWeight, FontWeight.w600);
    });

    test('styles task #N with ref colors', () {
      final span = buildInlineRefAwareSpan(
        text: 'See task #42 for info',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
      );
      expect(span.children, isNotNull);
      expect(span.children!.length, 3);

      final refSpan = span.children![1] as TextSpan;
      expect(refSpan.text, 'task #42');
      expect(refSpan.style!.color, refColor);
      expect(refSpan.style!.backgroundColor, refBg);
    });

    test('handles mixed @mention, #channel, and task #N', () {
      final span = buildInlineRefAwareSpan(
        text: '@alice said check #general for task #5',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
      );
      expect(span.children, isNotNull);
      // @alice, " said check ", #general, " for ", task #5 = 5 spans
      expect(span.children!.length, 5);

      final mentionSpan = span.children![0] as TextSpan;
      expect(mentionSpan.text, '@alice');
      expect(mentionSpan.style!.color, mentionColor);

      final channelSpan = span.children![2] as TextSpan;
      expect(channelSpan.text, '#general');
      expect(channelSpan.style!.color, refColor);

      final taskSpan = span.children![4] as TextSpan;
      expect(taskSpan.text, 'task #5');
      expect(taskSpan.style!.color, refColor);
    });

    test('attaches TapGestureRecognizer for onChannelRefTap', () {
      final tappedChannels = <String>[];
      final recognizers = <GestureRecognizer>[];
      final span = buildInlineRefAwareSpan(
        text: 'Go to #general',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
        onChannelRefTap: (name) => tappedChannels.add(name),
        createdRecognizers: recognizers,
      );

      expect(recognizers.length, 1);
      final refSpan = span.children![1] as TextSpan;
      expect(refSpan.recognizer, isA<TapGestureRecognizer>());

      // Simulate tap
      (refSpan.recognizer! as TapGestureRecognizer).onTap!();
      expect(tappedChannels, ['general']);

      for (final r in recognizers) {
        r.dispose();
      }
    });

    test('attaches TapGestureRecognizer for onTaskRefTap', () {
      final tappedTasks = <String>[];
      final recognizers = <GestureRecognizer>[];
      final span = buildInlineRefAwareSpan(
        text: 'See task #42',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
        onTaskRefTap: (number) => tappedTasks.add(number),
        createdRecognizers: recognizers,
      );

      expect(recognizers.length, 1);
      final refSpan = span.children![1] as TextSpan;
      expect(refSpan.recognizer, isA<TapGestureRecognizer>());

      // Simulate tap
      (refSpan.recognizer! as TapGestureRecognizer).onTap!();
      expect(tappedTasks, ['42']);

      for (final r in recognizers) {
        r.dispose();
      }
    });

    test('attaches TapGestureRecognizer for onMentionTap', () {
      final tappedMentions = <String>[];
      final recognizers = <GestureRecognizer>[];
      final span = buildInlineRefAwareSpan(
        text: 'Hey @alice',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
        onMentionTap: (name) => tappedMentions.add(name),
        createdRecognizers: recognizers,
      );

      expect(recognizers.length, 1);
      final mentionSpan = span.children![1] as TextSpan;
      (mentionSpan.recognizer! as TapGestureRecognizer).onTap!();
      expect(tappedMentions, ['alice']);

      for (final r in recognizers) {
        r.dispose();
      }
    });

    test('does not match email as #channel (test@example.com)', () {
      final span = buildInlineRefAwareSpan(
        text: 'Contact test@example.com or visit #support',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
      );
      // Should find #support but not parse test@example.com as mention
      expect(span.children, isNotNull);
      final allText = span.children!.cast<TextSpan>().map((s) => s.text).join();
      expect(allText, contains('#support'));
      // email should appear as plain text
      expect(allText, contains('test@example.com'));
    });

    test('does not match "subtask #3" as task ref', () {
      final span = buildInlineRefAwareSpan(
        text: 'Work on subtask #3',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
      );
      // "subtask #3" should NOT match — no task ref styling
      // But "#3" might match as a channel ref... let's verify
      // Actually with the combined regex, "subtask" has "task" in it but
      // preceded by "sub" which is a word char, so it should NOT match.
      // And bare "#3" preceded by space should match as channel_ref.
      expect(span.children, isNotNull);
      // Find spans with task ref style — none should exist
      final taskRefSpans = span.children!.cast<TextSpan>().where(
            (s) => s.text != null && s.text!.startsWith('task'),
          );
      expect(taskRefSpans, isEmpty);
    });

    test('composes with highlight query', () {
      final span = buildInlineRefAwareSpan(
        text: 'Check #general now',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
        highlightQuery: 'Check',
        highlightColor: Colors.yellow,
      );
      expect(span.children, isNotNull);
      expect(span.children!.length, greaterThan(2));
    });

    test('does not match "task #3x" as task ref (trailing boundary)', () {
      final span = buildInlineRefAwareSpan(
        text: 'See task #3x for details',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
      );
      // "task #3x" should NOT be styled as task ref
      if (span.children != null) {
        final taskRefSpans = span.children!.cast<TextSpan>().where(
              (s) => s.text != null && s.text!.contains('task #3'),
            );
        for (final s in taskRefSpans) {
          expect(s.style?.color, isNot(refColor),
              reason:
                  'Removing trailing boundary from combined regex → test RED');
        }
      }
    });

    test('does not match "task #3-foo" as task ref (trailing boundary)', () {
      final span = buildInlineRefAwareSpan(
        text: 'Work on task #3-foo now',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
      );
      if (span.children != null) {
        final taskRefSpans = span.children!.cast<TextSpan>().where(
              (s) => s.text != null && s.text!.contains('task #3'),
            );
        for (final s in taskRefSpans) {
          expect(s.style?.color, isNot(refColor),
              reason:
                  'Removing trailing boundary from combined regex → test RED');
        }
      }
    });
  });

  group('Syntax priority — TaskRefSyntax before ChannelRefSyntax', () {
    late md.Document document;

    setUp(() {
      // Mirror production order: TaskRefSyntax first, then ChannelRefSyntax
      document = md.Document(
        inlineSyntaxes: [TaskRefSyntax(), ChannelRefSyntax()],
        extensionSet: md.ExtensionSet.none,
      );
    });

    test('"task #5" is parsed as task_ref, not channel_ref on "5"', () {
      final nodes = document.parseInline('task #5');
      final taskRefs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'task_ref');
      final channelRefs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'channel_ref');
      expect(taskRefs.length, 1);
      expect(channelRefs, isEmpty);
    });

    test('#general after "task #5" is still parsed as channel_ref', () {
      final nodes = document.parseInline('task #5 in #general');
      final taskRefs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'task_ref');
      final channelRefs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'channel_ref');
      expect(taskRefs.length, 1);
      expect(channelRefs.length, 1);
      expect(taskRefs.first.attributes['number'], '5');
      expect(channelRefs.first.attributes['name'], 'general');
    });
  });
}
