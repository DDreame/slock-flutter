import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/presentation/widgets/formatting_toolbar.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Integration-level tests that prove the formatting toolbar correctly syncs
/// draft state through the onChanged callback — the same wiring used in
/// `_ConversationComposer`.
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

  group('FormattingToolbar — draft sync integration', () {
    testWidgets(
        'toolbar tap syncs draft through onChanged and survives rebuild',
        (tester) async {
      // Simulate the composer's draft state: a local String that
      // represents what the store's draft field would be.
      var draft = '';
      const toolbarVisible = true;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                // Mirror the composer's rebuild logic: if draft diverges
                // from controller, overwrite controller (same as
                // _ConversationDetailScreenState.build lines 190-195).
                if (controller.text != draft) {
                  controller.value = TextEditingValue(
                    text: draft,
                    selection: TextSelection.collapsed(offset: draft.length),
                  );
                }
                return Column(
                  children: [
                    FormattingToolbar(
                      controller: controller,
                      visible: toolbarVisible,
                      focusNode: focusNode,
                      onChanged: (value) {
                        setState(() {
                          draft = value;
                        });
                      },
                    ),
                    TextField(
                      key: const ValueKey('composer-input'),
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (value) {
                        setState(() {
                          draft = value;
                        });
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Initially empty.
      expect(controller.text, '');
      expect(draft, '');

      // Tap bold — should insert placeholder and sync draft.
      await tester.tap(find.byKey(const ValueKey('toolbar-bold')));
      await tester.pump();

      expect(controller.text, '**bold**');
      expect(draft, '**bold**', reason: 'draft must be synced via onChanged');

      // Force a rebuild (simulates any state change triggering build).
      // The draft-divergence guard should NOT overwrite the controller
      // because draft and controller.text now agree.
      await tester.pump();

      expect(controller.text, '**bold**',
          reason: 'formatted text must survive rebuild');
      expect(draft, '**bold**');
    });

    testWidgets('canSend becomes true after toolbar inserts text',
        (tester) async {
      var draft = '';

      bool canSend() => draft.trim().isNotEmpty;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                if (controller.text != draft) {
                  controller.value = TextEditingValue(
                    text: draft,
                    selection: TextSelection.collapsed(offset: draft.length),
                  );
                }
                return Column(
                  children: [
                    FormattingToolbar(
                      controller: controller,
                      visible: true,
                      focusNode: focusNode,
                      onChanged: (value) {
                        setState(() {
                          draft = value;
                        });
                      },
                    ),
                    // Show send or mic based on canSend, like the real composer.
                    if (canSend())
                      const Icon(Icons.send, key: ValueKey('send-icon'))
                    else
                      const Icon(Icons.mic, key: ValueKey('mic-icon')),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Initially mic is shown.
      expect(find.byKey(const ValueKey('mic-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('send-icon')), findsNothing);

      // Tap italic — should switch to send.
      await tester.tap(find.byKey(const ValueKey('toolbar-italic')));
      await tester.pump();

      expect(find.byKey(const ValueKey('send-icon')), findsOneWidget,
          reason: 'canSend must be true after toolbar inserts text');
      expect(find.byKey(const ValueKey('mic-icon')), findsNothing);
    });

    testWidgets('toolbar wraps selected text and syncs draft', (tester) async {
      var draft = 'hello world';

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                if (controller.text != draft) {
                  controller.value = TextEditingValue(
                    text: draft,
                    selection: TextSelection.collapsed(offset: draft.length),
                  );
                }
                return Column(
                  children: [
                    FormattingToolbar(
                      controller: controller,
                      visible: true,
                      focusNode: focusNode,
                      onChanged: (value) {
                        setState(() {
                          draft = value;
                        });
                      },
                    ),
                    TextField(
                      key: const ValueKey('composer-input'),
                      controller: controller,
                      focusNode: focusNode,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Select 'world' (offsets 6-11).
      controller.selection =
          const TextSelection(baseOffset: 6, extentOffset: 11);
      await tester.pump();

      // Tap bold to wrap selection.
      await tester.tap(find.byKey(const ValueKey('toolbar-bold')));
      await tester.pump();

      expect(controller.text, 'hello **world**');
      expect(draft, 'hello **world**',
          reason: 'draft must reflect wrapped text');

      // Rebuild should not clobber.
      await tester.pump();
      expect(controller.text, 'hello **world**');
    });

    testWidgets('toggle visibility hides and shows toolbar', (tester) async {
      var toolbarVisible = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    IconButton(
                      key: const ValueKey('toggle-btn'),
                      icon: const Icon(Icons.text_format),
                      onPressed: () {
                        setState(() {
                          toolbarVisible = !toolbarVisible;
                        });
                      },
                    ),
                    FormattingToolbar(
                      controller: controller,
                      visible: toolbarVisible,
                      focusNode: focusNode,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Toolbar hidden initially.
      expect(find.byKey(const ValueKey('formatting-toolbar')), findsNothing);

      // Tap toggle — toolbar appears.
      await tester.tap(find.byKey(const ValueKey('toggle-btn')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('formatting-toolbar')),
        findsOneWidget,
      );

      // Tap toggle again — toolbar hides.
      await tester.tap(find.byKey(const ValueKey('toggle-btn')));
      await tester.pump();
      expect(find.byKey(const ValueKey('formatting-toolbar')), findsNothing);
    });
  });
}
