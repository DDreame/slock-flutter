import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/presentation/widgets/formatting_toolbar.dart';

void main() {
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Widget buildToolbar({bool visible = true}) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Column(
          children: [
            FormattingToolbar(
              controller: controller,
              visible: visible,
              focusNode: focusNode,
            ),
            TextField(
              controller: controller,
              focusNode: focusNode,
            ),
          ],
        ),
      ),
    );
  }

  group('FormattingToolbar — visibility', () {
    testWidgets('renders toolbar when visible is true', (tester) async {
      await tester.pumpWidget(buildToolbar(visible: true));

      expect(
        find.byKey(const ValueKey('formatting-toolbar')),
        findsOneWidget,
      );
    });

    testWidgets('hides toolbar when visible is false', (tester) async {
      await tester.pumpWidget(buildToolbar(visible: false));

      expect(
        find.byKey(const ValueKey('formatting-toolbar')),
        findsNothing,
      );
    });
  });

  group('FormattingToolbar — buttons present', () {
    testWidgets('shows all five format buttons', (tester) async {
      await tester.pumpWidget(buildToolbar());

      expect(find.byKey(const ValueKey('toolbar-bold')), findsOneWidget);
      expect(find.byKey(const ValueKey('toolbar-italic')), findsOneWidget);
      expect(find.byKey(const ValueKey('toolbar-code')), findsOneWidget);
      expect(find.byKey(const ValueKey('toolbar-codeblock')), findsOneWidget);
      expect(find.byKey(const ValueKey('toolbar-link')), findsOneWidget);
    });
  });

  group('FormattingToolbar — button taps', () {
    testWidgets('tapping bold button inserts bold placeholder', (tester) async {
      await tester.pumpWidget(buildToolbar());

      controller.text = '';
      controller.selection = const TextSelection.collapsed(offset: 0);

      await tester.tap(find.byKey(const ValueKey('toolbar-bold')));
      await tester.pump();

      expect(controller.text, '**bold**');
    });

    testWidgets('tapping italic button inserts italic placeholder',
        (tester) async {
      await tester.pumpWidget(buildToolbar());

      controller.text = '';
      controller.selection = const TextSelection.collapsed(offset: 0);

      await tester.tap(find.byKey(const ValueKey('toolbar-italic')));
      await tester.pump();

      expect(controller.text, '*italic*');
    });

    testWidgets('tapping code button inserts code placeholder', (tester) async {
      await tester.pumpWidget(buildToolbar());

      controller.text = '';
      controller.selection = const TextSelection.collapsed(offset: 0);

      await tester.tap(find.byKey(const ValueKey('toolbar-code')));
      await tester.pump();

      expect(controller.text, '`code`');
    });

    testWidgets('tapping code block button inserts code block placeholder',
        (tester) async {
      await tester.pumpWidget(buildToolbar());

      controller.text = '';
      controller.selection = const TextSelection.collapsed(offset: 0);

      await tester.tap(find.byKey(const ValueKey('toolbar-codeblock')));
      await tester.pump();

      expect(controller.text, '```\ncode\n```');
    });

    testWidgets('tapping link button inserts link placeholder', (tester) async {
      await tester.pumpWidget(buildToolbar());

      controller.text = '';
      controller.selection = const TextSelection.collapsed(offset: 0);

      await tester.tap(find.byKey(const ValueKey('toolbar-link')));
      await tester.pump();

      expect(controller.text, '[text](url)');
    });
  });
}
