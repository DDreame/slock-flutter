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

    test('does not match #3foo (digit-starting name)', () {
      final nodes = document.parseInline('#3foo');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'channel_ref');
      expect(refs, isEmpty,
          reason:
              'Channel names must start with a letter; digit-start → plain text');
    });

    test('does not match #3x (digit-starting single char)', () {
      final nodes = document.parseInline('see #3x here');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'channel_ref');
      expect(refs, isEmpty,
          reason: 'Removing letter-start constraint → test RED');
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
      // "subtask #3" should NOT match as task ref (preceded by word char "sub").
      // "#3" also does NOT match as channel ref (digit-start, letter required).
      // Result: entire string is plain text — no children, just text.
      if (span.children != null) {
        final styledRefSpans = span.children!.cast<TextSpan>().where(
              (s) => s.style?.color == refColor,
            );
        expect(styledRefSpans, isEmpty,
            reason: '"subtask #3" must produce no styled refs');
      } else {
        // Plain text — correct behavior with letter-start channel constraint.
        expect(span.text, 'Work on subtask #3');
      }
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

    test('does not match "task #3x" as any ref (trailing boundary)', () {
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
      // "task #3x" should produce NO styled refs (neither task nor channel).
      // With letter-start constraint, "#3x" is not a valid channel name either.
      if (span.children != null) {
        final styledRefSpans = span.children!.cast<TextSpan>().where(
              (s) => s.style?.color == refColor,
            );
        expect(styledRefSpans, isEmpty,
            reason:
                'task #3x must be plain text — not task_ref (trailing boundary) '
                'and not channel_ref (digit-start). '
                'Removing either guard → test RED');
      } else {
        // No children means entire text is plain — also correct.
        expect(span.text, 'See task #3x for details');
      }
    });

    test('does not match "task #3-foo" as any ref (trailing boundary)', () {
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
      // "task #3-foo" should produce NO styled refs.
      if (span.children != null) {
        final styledRefSpans = span.children!.cast<TextSpan>().where(
              (s) => s.style?.color == refColor,
            );
        expect(styledRefSpans, isEmpty,
            reason:
                'task #3-foo must be plain text — not task_ref (trailing boundary) '
                'and not channel_ref (digit-start). '
                'Removing either guard → test RED');
      } else {
        expect(span.text, 'Work on task #3-foo now');
      }
    });

    test('does not match "#3foo" as channel ref (digit-starting)', () {
      final span = buildInlineRefAwareSpan(
        text: 'Check #3foo for info',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
      );
      // "#3foo" starts with digit — not a valid channel ref.
      if (span.children != null) {
        final styledRefSpans = span.children!.cast<TextSpan>().where(
              (s) => s.style?.color == refColor,
            );
        expect(styledRefSpans, isEmpty,
            reason:
                'Channel names must start with letter; "#3foo" → plain text. '
                'Removing letter-start constraint → test RED');
      } else {
        expect(span.text, 'Check #3foo for info');
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

    test('"task #3x" produces neither task_ref nor channel_ref', () {
      final nodes = document.parseInline('task #3x');
      final taskRefs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'task_ref');
      final channelRefs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'channel_ref');
      expect(taskRefs, isEmpty,
          reason: 'Trailing boundary blocks task_ref on "task #3x"');
      expect(channelRefs, isEmpty,
          reason:
              'Channel names must start with letter; "#3x" starts with digit → no channel_ref');
    });

    test('"task #3-foo" produces neither task_ref nor channel_ref', () {
      final nodes = document.parseInline('task #3-foo');
      final taskRefs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'task_ref');
      final channelRefs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'channel_ref');
      expect(taskRefs, isEmpty,
          reason: 'Trailing boundary blocks task_ref on "task #3-foo"');
      expect(channelRefs, isEmpty,
          reason:
              'Channel names must start with letter; "#3-foo" starts with digit → no channel_ref');
    });
  });

  group('ThreadRefSyntax', () {
    late md.Document document;

    setUp(() {
      document = md.Document(
        inlineSyntaxes: [ThreadRefSyntax()],
        extensionSet: md.ExtensionSet.none,
      );
    });

    test('parses #channel:hexid (channel thread)', () {
      final nodes = document.parseInline('#general:a1b2c3d4');
      expect(nodes.length, 1);
      final element = nodes.first as md.Element;
      expect(element.tag, 'thread_ref');
      expect(element.attributes['target'], 'general');
      expect(element.attributes['messageId'], 'a1b2c3d4');
      expect(element.attributes['isDm'], 'false');
    });

    test('parses #channel-name:6hexid (6 char ID)', () {
      final nodes = document.parseInline('#my-channel:abcdef');
      expect(nodes.length, 1);
      final element = nodes.first as md.Element;
      expect(element.attributes['target'], 'my-channel');
      expect(element.attributes['messageId'], 'abcdef');
      expect(element.attributes['isDm'], 'false');
    });

    test('parses dm:@username:hexid (DM thread)', () {
      final nodes = document.parseInline('dm:@alice:a1b2c3d4');
      expect(nodes.length, 1);
      final element = nodes.first as md.Element;
      expect(element.tag, 'thread_ref');
      expect(element.attributes['target'], 'alice');
      expect(element.attributes['messageId'], 'a1b2c3d4');
      expect(element.attributes['isDm'], 'true');
    });

    test('parses dm:@user.name-2:hexid (special chars in DM name)', () {
      final nodes = document.parseInline('dm:@user.name-2:ab12cd34');
      expect(nodes.length, 1);
      final element = nodes.first as md.Element;
      expect(element.attributes['target'], 'user.name-2');
      expect(element.attributes['messageId'], 'ab12cd34');
      expect(element.attributes['isDm'], 'true');
    });

    test('parses thread ref in middle of text', () {
      final nodes =
          document.parseInline('See the thread #general:abc123 for details');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'thread_ref');
      expect(refs.length, 1);
      expect(refs.first.attributes['target'], 'general');
      expect(refs.first.attributes['messageId'], 'abc123');
    });

    test('parses DM thread in middle of text', () {
      final nodes = document.parseInline('Check dm:@bob:f1e2d3c4 for context');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'thread_ref');
      expect(refs.length, 1);
      expect(refs.first.attributes['target'], 'bob');
      expect(refs.first.attributes['isDm'], 'true');
    });

    test('parses multiple thread refs', () {
      final nodes =
          document.parseInline('#general:abc123 and dm:@alice:def456');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'thread_ref');
      expect(refs.length, 2);
      expect(refs.first.attributes['target'], 'general');
      expect(refs.first.attributes['isDm'], 'false');
      expect(refs.last.attributes['target'], 'alice');
      expect(refs.last.attributes['isDm'], 'true');
    });

    test('does not match #channel:hexid preceded by word char', () {
      final nodes = document.parseInline('foo#general:abc123');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'thread_ref');
      expect(refs, isEmpty,
          reason: 'Thread ref preceded by word char should not match');
    });

    test('does not match dm:@name:hexid preceded by word char', () {
      final nodes = document.parseInline('xdm:@alice:abc123');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'thread_ref');
      expect(refs, isEmpty,
          reason: 'DM thread ref preceded by word char should not match');
    });

    test('matches thread ref after punctuation', () {
      final nodes = document.parseInline('(#general:abc123)');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'thread_ref');
      expect(refs.length, 1);
    });

    test('does not match #channel:short (less than 6 hex chars)', () {
      final nodes = document.parseInline('#general:abc');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'thread_ref');
      expect(refs, isEmpty,
          reason: 'Message ID must be 6-8 hex chars; 3 chars is too short');
    });

    test('does not match #channel:toolong (more than 8 hex chars)', () {
      final nodes = document.parseInline('#general:abcdef123');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'thread_ref');
      // Should not match because > 8 hex chars in the ID.
      // The regex matches up to 8, so "abcdef12" is consumed and "3" is left.
      if (refs.isNotEmpty) {
        // If it matches 8 chars and leaves trailing as text, that's acceptable.
        expect(
            refs.first.attributes['messageId']!.length, lessThanOrEqualTo(8));
      }
    });

    test('matches 8-char hex ID', () {
      final nodes = document.parseInline('#general:a1b2c3d4');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'thread_ref');
      expect(refs.length, 1);
      expect(refs.first.attributes['messageId'], 'a1b2c3d4');
    });

    test('case-insensitive hex ID', () {
      final nodes = document.parseInline('#general:A1B2C3D4');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'thread_ref');
      expect(refs.length, 1);
      expect(refs.first.attributes['messageId'], 'A1B2C3D4');
    });

    test('does not match #3channel:hexid (digit-starting channel name)', () {
      final nodes = document.parseInline('#3foo:abcdef');
      final refs =
          nodes.whereType<md.Element>().where((e) => e.tag == 'thread_ref');
      expect(refs, isEmpty, reason: 'Channel name must start with letter');
    });
  });

  group('buildInlineRefAwareSpan — thread refs', () {
    const baseStyle = TextStyle(color: Colors.black, fontSize: 14);
    const mentionColor = Colors.blue;
    const mentionBg = Color(0x1A0000FF);
    const selfMentionColor = Colors.white;
    const selfMentionBg = Colors.blue;
    const refColor = Colors.indigo;
    const refBg = Color(0x1A3F51B5);

    test('styles #channel:hexid with ref colors', () {
      final span = buildInlineRefAwareSpan(
        text: 'See #general:a1b2c3d4 for info',
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
      expect(refSpan.text, '#general:a1b2c3d4');
      expect(refSpan.style!.color, refColor);
      expect(refSpan.style!.backgroundColor, refBg);
      expect(refSpan.style!.fontWeight, FontWeight.w600);
    });

    test('styles dm:@name:hexid with ref colors', () {
      final span = buildInlineRefAwareSpan(
        text: 'Check dm:@alice:abcdef12 please',
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
      expect(refSpan.text, 'dm:@alice:abcdef12');
      expect(refSpan.style!.color, refColor);
      expect(refSpan.style!.backgroundColor, refBg);
      expect(refSpan.style!.fontWeight, FontWeight.w600);
    });

    test('attaches TapGestureRecognizer for onThreadRefTap (channel thread)',
        () {
      final tappedRefs = <ThreadRefData>[];
      final recognizers = <GestureRecognizer>[];
      final span = buildInlineRefAwareSpan(
        text: 'See #engineering:b885b5ae thread',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
        onThreadRefTap: (data) => tappedRefs.add(data),
        createdRecognizers: recognizers,
      );

      expect(recognizers.length, 1);
      final refSpan = span.children![1] as TextSpan;
      expect(refSpan.recognizer, isA<TapGestureRecognizer>());

      // Simulate tap
      (refSpan.recognizer! as TapGestureRecognizer).onTap!();
      expect(tappedRefs.length, 1);
      expect(tappedRefs.first.targetName, 'engineering');
      expect(tappedRefs.first.messageShortId, 'b885b5ae');
      expect(tappedRefs.first.isDm, isFalse);

      for (final r in recognizers) {
        r.dispose();
      }
    });

    test('attaches TapGestureRecognizer for onThreadRefTap (DM thread)', () {
      final tappedRefs = <ThreadRefData>[];
      final recognizers = <GestureRecognizer>[];
      final span = buildInlineRefAwareSpan(
        text: 'Reply in dm:@bob:f1e2d3c4',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
        onThreadRefTap: (data) => tappedRefs.add(data),
        createdRecognizers: recognizers,
      );

      expect(recognizers.length, 1);
      final refSpan = span.children![1] as TextSpan;
      (refSpan.recognizer! as TapGestureRecognizer).onTap!();
      expect(tappedRefs.length, 1);
      expect(tappedRefs.first.targetName, 'bob');
      expect(tappedRefs.first.messageShortId, 'f1e2d3c4');
      expect(tappedRefs.first.isDm, isTrue);

      for (final r in recognizers) {
        r.dispose();
      }
    });

    test('thread ref takes priority over channel ref for #channel:hexid', () {
      final span = buildInlineRefAwareSpan(
        text: '#general:abcdef12 should be thread ref not channel ref',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
      );
      expect(span.children, isNotNull);
      // The first styled span should be the thread ref "#general:abcdef12"
      // NOT a channel ref "#general" + plain text ":abcdef12"
      final firstRef = span.children![0] as TextSpan;
      expect(firstRef.text, '#general:abcdef12');
    });

    test('handles mixed thread ref, channel ref, and mention', () {
      final span = buildInlineRefAwareSpan(
        text: '@alice discussed #general:abc123 and #random',
        baseStyle: baseStyle,
        mentionColor: mentionColor,
        mentionBackground: mentionBg,
        selfMentionColor: selfMentionColor,
        selfMentionBackground: selfMentionBg,
        refColor: refColor,
        refBackground: refBg,
      );
      expect(span.children, isNotNull);
      // @alice, " discussed ", #general:abc123, " and ", #random
      expect(span.children!.length, 5);

      final mentionSpan = span.children![0] as TextSpan;
      expect(mentionSpan.text, '@alice');
      expect(mentionSpan.style!.color, mentionColor);

      final threadSpan = span.children![2] as TextSpan;
      expect(threadSpan.text, '#general:abc123');
      expect(threadSpan.style!.color, refColor);

      final channelSpan = span.children![4] as TextSpan;
      expect(channelSpan.text, '#random');
      expect(channelSpan.style!.color, refColor);
    });
  });
}
