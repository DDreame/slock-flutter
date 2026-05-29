import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/utils/strip_markdown.dart';

void main() {
  group('stripMarkdown', () {
    test('strips bold formatting', () {
      expect(stripMarkdown('**bold** text'), 'bold text');
      expect(stripMarkdown('__bold__ text'), 'bold text');
    });

    test('strips italic formatting', () {
      expect(stripMarkdown('*italic* text'), 'italic text');
      expect(stripMarkdown('_italic_ text'), 'italic text');
    });

    test('strips bold+italic formatting', () {
      expect(stripMarkdown('***bolditalic*** text'), 'bolditalic text');
    });

    test('strips strikethrough', () {
      expect(stripMarkdown('~~deleted~~ text'), 'deleted text');
    });

    test('strips inline code', () {
      expect(stripMarkdown('use `foo()` here'), 'use foo() here');
    });

    test('strips links', () {
      expect(stripMarkdown('[click](https://x.com)'), 'click');
    });

    test('strips images', () {
      expect(stripMarkdown('![alt](https://img.png)'), 'alt');
    });

    test('strips headings', () {
      expect(stripMarkdown('# Heading\ncontent'), 'Heading\ncontent');
      expect(stripMarkdown('## Sub'), 'Sub');
    });

    test('strips blockquotes', () {
      expect(stripMarkdown('> quoted text'), 'quoted text');
    });

    test('strips unordered list markers', () {
      expect(stripMarkdown('- item one\n- item two'), 'item one\nitem two');
    });

    test('strips ordered list markers', () {
      expect(stripMarkdown('1. first\n2. second'), 'first\nsecond');
    });

    test('strips code fences', () {
      expect(
        stripMarkdown('```dart\nfinal x = 1;\n```'),
        'final x = 1;',
      );
    });

    test('preserves @mentions and #channel refs', () {
      expect(
        stripMarkdown('**bold** @alice #general'),
        'bold @alice #general',
      );
    });

    test('plain text passes through unchanged', () {
      expect(stripMarkdown('hello world'), 'hello world');
    });

    test('complex message with mixed formatting', () {
      const input = '**Hello** @alice, check [docs](http://x.com) '
          'in #general and use `cmd`';
      const expected = 'Hello @alice, check docs '
          'in #general and use cmd';
      expect(stripMarkdown(input), expected);
    });
  });
}
