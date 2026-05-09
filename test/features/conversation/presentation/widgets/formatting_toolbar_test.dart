import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/presentation/widgets/formatting_toolbar.dart';

void main() {
  late TextEditingController controller;

  setUp(() {
    controller = TextEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  group('applyMarkdownFormat — bold', () {
    test('wraps selected text with **', () {
      controller.text = 'hello world';
      controller.selection =
          const TextSelection(baseOffset: 6, extentOffset: 11);

      applyMarkdownFormat(controller, MarkdownFormat.bold);

      expect(controller.text, 'hello **world**');
      // Cursor should be after the wrapped text, before closing markers.
      expect(controller.selection, const TextSelection.collapsed(offset: 14));
    });

    test('inserts bold placeholder at cursor when no selection', () {
      controller.text = 'hello ';
      controller.selection = const TextSelection.collapsed(offset: 6);

      applyMarkdownFormat(controller, MarkdownFormat.bold);

      expect(controller.text, 'hello **bold**');
      // Placeholder text should be selected for easy overwrite.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 8, extentOffset: 12),
      );
    });
  });

  group('applyMarkdownFormat — italic', () {
    test('wraps selected text with *', () {
      controller.text = 'hello world';
      controller.selection =
          const TextSelection(baseOffset: 6, extentOffset: 11);

      applyMarkdownFormat(controller, MarkdownFormat.italic);

      expect(controller.text, 'hello *world*');
      expect(controller.selection, const TextSelection.collapsed(offset: 12));
    });

    test('inserts italic placeholder at cursor when no selection', () {
      controller.text = 'hello ';
      controller.selection = const TextSelection.collapsed(offset: 6);

      applyMarkdownFormat(controller, MarkdownFormat.italic);

      expect(controller.text, 'hello *italic*');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 7, extentOffset: 13),
      );
    });
  });

  group('applyMarkdownFormat — inlineCode', () {
    test('wraps selected text with backtick', () {
      controller.text = 'run command';
      controller.selection =
          const TextSelection(baseOffset: 4, extentOffset: 11);

      applyMarkdownFormat(controller, MarkdownFormat.inlineCode);

      expect(controller.text, 'run `command`');
      expect(controller.selection, const TextSelection.collapsed(offset: 12));
    });

    test('inserts code placeholder at cursor when no selection', () {
      controller.text = '';
      controller.selection = const TextSelection.collapsed(offset: 0);

      applyMarkdownFormat(controller, MarkdownFormat.inlineCode);

      expect(controller.text, '`code`');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 5),
      );
    });
  });

  group('applyMarkdownFormat — codeBlock', () {
    test('wraps selected text with triple backticks', () {
      controller.text = 'print("hi")';
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 11);

      applyMarkdownFormat(controller, MarkdownFormat.codeBlock);

      expect(controller.text, '```\nprint("hi")\n```');
      expect(controller.selection, const TextSelection.collapsed(offset: 15));
    });

    test('inserts code block placeholder at cursor when no selection', () {
      controller.text = '';
      controller.selection = const TextSelection.collapsed(offset: 0);

      applyMarkdownFormat(controller, MarkdownFormat.codeBlock);

      expect(controller.text, '```\ncode\n```');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 4, extentOffset: 8),
      );
    });
  });

  group('applyMarkdownFormat — link', () {
    test('wraps selected text as link label', () {
      controller.text = 'click here';
      controller.selection =
          const TextSelection(baseOffset: 6, extentOffset: 10);

      applyMarkdownFormat(controller, MarkdownFormat.link);

      expect(controller.text, 'click [here](url)');
      // The 'url' placeholder should be selected for easy overwrite.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 13, extentOffset: 16),
      );
    });

    test('inserts link placeholder at cursor when no selection', () {
      controller.text = '';
      controller.selection = const TextSelection.collapsed(offset: 0);

      applyMarkdownFormat(controller, MarkdownFormat.link);

      expect(controller.text, '[text](url)');
      // The 'url' placeholder should be selected.
      expect(
        controller.selection,
        const TextSelection(baseOffset: 7, extentOffset: 10),
      );
    });
  });

  group('applyMarkdownFormat — cursor at end of text', () {
    test('bold at end inserts placeholder', () {
      controller.text = 'hello';
      controller.selection = const TextSelection.collapsed(offset: 5);

      applyMarkdownFormat(controller, MarkdownFormat.bold);

      expect(controller.text, 'hello**bold**');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 7, extentOffset: 11),
      );
    });
  });

  group('applyMarkdownFormat — mid-text cursor', () {
    test('bold at mid-text inserts at cursor position', () {
      controller.text = 'hello world';
      controller.selection = const TextSelection.collapsed(offset: 5);

      applyMarkdownFormat(controller, MarkdownFormat.bold);

      expect(controller.text, 'hello**bold** world');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 7, extentOffset: 11),
      );
    });
  });
}
