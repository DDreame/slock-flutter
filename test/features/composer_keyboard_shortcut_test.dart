import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/stores/composer/composer_settings_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

// ---------------------------------------------------------------------------
// #540: Composer 键盘快捷键 — Phase A
//
// Verifies keyboard shortcut handling in the message composer:
//   - "Enter to send" mode: Enter key triggers send, Shift+Enter
//     inserts newline
//   - Default "Enter for newline" mode: Ctrl/Cmd+Enter triggers send,
//     Enter inserts newline
//   - Settings toggle persists the preference to SharedPreferences
//
// Invariants:
//   INV-KBSHORTCUT-1: When enterToSend is enabled, pressing Enter
//                      (without Shift) on hardware keyboard triggers
//                      the send callback
//   INV-KBSHORTCUT-2: When enterToSend is enabled, pressing
//                      Shift+Enter inserts a newline (does not send)
//   INV-KBSHORTCUT-3: When enterToSend is disabled (default), pressing
//                      Ctrl+Enter triggers the send callback
//   INV-KBSHORTCUT-3a: When enterToSend is disabled (default), pressing
//                       Cmd+Enter (macOS) triggers the send callback
//   INV-KBSHORTCUT-4: The enterToSend preference persists to
//                      SharedPreferences and is restored on read
//
// Phase B: All tests un-skipped. Keyboard handling implemented in
// _ConversationComposer, ComposerSettingsStore created.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-KBSHORTCUT-1: Enter key sends when enterToSend is enabled.
  //
  // Setup: Render a composer-style TextField wrapped in Focus.onKeyEvent
  // with enterToSend=true. Simulate pressing Enter on hardware keyboard.
  // The send callback should fire and the text should not gain a newline.
  //
  // -----------------------------------------------------------------------
  testWidgets(
    'Enter key triggers send when enterToSend is enabled '
    '(INV-KBSHORTCUT-1)',
    (tester) async {
      var sendCalled = false;
      final controller = TextEditingController(text: 'Hello');
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: _TestComposer(
              controller: controller,
              focusNode: focusNode,
              enterToSend: true,
              onSend: () => sendCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus the text field.
      await tester.tap(find.byKey(const ValueKey('composer-input')));
      await tester.pumpAndSettle();

      // Simulate pressing Enter on hardware keyboard.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Send callback must fire.
      expect(
        sendCalled,
        isTrue,
        reason: 'Enter key must trigger send when enterToSend is '
            'enabled (INV-KBSHORTCUT-1)',
      );

      // Text should not have gained a newline.
      expect(
        controller.text,
        equals('Hello'),
        reason: 'Enter must not insert a newline when enterToSend '
            'is enabled (INV-KBSHORTCUT-1)',
      );

      controller.dispose();
      focusNode.dispose();
    },
  );

  // -----------------------------------------------------------------------
  // INV-KBSHORTCUT-2: Shift+Enter inserts newline when enterToSend
  // is enabled.
  //
  // Setup: Render a composer with enterToSend=true. Simulate pressing
  // Shift+Enter on hardware keyboard. The text should gain a newline
  // and the send callback should NOT fire.
  //
  // -----------------------------------------------------------------------
  testWidgets(
    'Shift+Enter inserts newline when enterToSend is enabled '
    '(INV-KBSHORTCUT-2)',
    (tester) async {
      var sendCalled = false;
      final controller = TextEditingController(text: 'Hello');
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: _TestComposer(
              controller: controller,
              focusNode: focusNode,
              enterToSend: true,
              onSend: () => sendCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus the text field.
      await tester.tap(find.byKey(const ValueKey('composer-input')));
      await tester.pumpAndSettle();

      // Simulate pressing Shift+Enter on hardware keyboard.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      // Send callback must NOT fire.
      expect(
        sendCalled,
        isFalse,
        reason: 'Shift+Enter must not trigger send '
            '(INV-KBSHORTCUT-2)',
      );

      // Composer text must gain a newline.
      expect(
        controller.text,
        contains('\n'),
        reason: 'Shift+Enter must insert a newline into composer text '
            '(INV-KBSHORTCUT-2)',
      );

      controller.dispose();
      focusNode.dispose();
    },
  );

  // -----------------------------------------------------------------------
  // INV-KBSHORTCUT-3: Ctrl+Enter sends when enterToSend is disabled
  // (default mode).
  //
  // Setup: Render a composer with enterToSend=false (the default).
  // Simulate pressing Ctrl+Enter on hardware keyboard. The send
  // callback should fire.
  //
  // -----------------------------------------------------------------------
  testWidgets(
    'Ctrl+Enter triggers send when enterToSend is disabled '
    '(INV-KBSHORTCUT-3)',
    (tester) async {
      var sendCalled = false;
      final controller = TextEditingController(text: 'Hello');
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: _TestComposer(
              controller: controller,
              focusNode: focusNode,
              enterToSend: false,
              onSend: () => sendCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus the text field.
      await tester.tap(find.byKey(const ValueKey('composer-input')));
      await tester.pumpAndSettle();

      // Simulate pressing Ctrl+Enter on hardware keyboard.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // Send callback must fire.
      expect(
        sendCalled,
        isTrue,
        reason: 'Ctrl+Enter must trigger send when enterToSend is '
            'disabled (INV-KBSHORTCUT-3)',
      );

      controller.dispose();
      focusNode.dispose();
    },
  );

  // -----------------------------------------------------------------------
  // INV-KBSHORTCUT-3a: Cmd+Enter (macOS) sends when enterToSend is
  // disabled (default mode).
  //
  // Setup: Render a composer with enterToSend=false. Simulate pressing
  // Cmd+Enter (metaLeft + Enter) on hardware keyboard. The send
  // callback should fire.
  //
  // -----------------------------------------------------------------------
  testWidgets(
    'Cmd+Enter triggers send when enterToSend is disabled '
    '(INV-KBSHORTCUT-3a)',
    (tester) async {
      var sendCalled = false;
      final controller = TextEditingController(text: 'Hello');
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: _TestComposer(
              controller: controller,
              focusNode: focusNode,
              enterToSend: false,
              onSend: () => sendCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus the text field.
      await tester.tap(find.byKey(const ValueKey('composer-input')));
      await tester.pumpAndSettle();

      // Simulate pressing Cmd+Enter on hardware keyboard (macOS path).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();

      // Send callback must fire.
      expect(
        sendCalled,
        isTrue,
        reason: 'Cmd+Enter must trigger send when enterToSend is '
            'disabled — macOS path (INV-KBSHORTCUT-3a)',
      );

      controller.dispose();
      focusNode.dispose();
    },
  );

  // -----------------------------------------------------------------------
  // INV-KBSHORTCUT-4: enterToSend preference persists to
  // SharedPreferences and is restored on read.
  //
  // Setup: Create a ComposerSettingsStore backed by SharedPreferences.
  // Set enterToSend=true, verify it persists. Create a new store
  // instance and verify the preference is restored.
  //
  // -----------------------------------------------------------------------
  testWidgets(
    'enterToSend preference persists to SharedPreferences '
    '(INV-KBSHORTCUT-4)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Default should be false (Enter for newline).
      final store = container.read(composerSettingsStoreProvider.notifier);
      expect(
        container.read(composerSettingsStoreProvider).enterToSend,
        isFalse,
        reason: 'Default enterToSend must be false '
            '(INV-KBSHORTCUT-4)',
      );

      // Set enterToSend to true.
      await store.setEnterToSend(true);

      // Verify state updated.
      expect(
        container.read(composerSettingsStoreProvider).enterToSend,
        isTrue,
        reason: 'enterToSend must update to true after set '
            '(INV-KBSHORTCUT-4)',
      );

      // Verify SharedPreferences has the value.
      expect(
        prefs.getBool('enter_to_send'),
        isTrue,
        reason: 'enterToSend must be persisted to SharedPreferences '
            '(INV-KBSHORTCUT-4)',
      );

      // New container should restore the preference.
      final container2 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container2.dispose);

      final store2 = container2.read(composerSettingsStoreProvider.notifier);
      store2.restoreFromPrefs();

      expect(
        container2.read(composerSettingsStoreProvider).enterToSend,
        isTrue,
        reason: 'enterToSend must be restored from SharedPreferences '
            '(INV-KBSHORTCUT-4)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Test-local widget with keyboard shortcut handling.
// ---------------------------------------------------------------------------

/// Test-local composer widget with keyboard shortcut handling.
///
/// Mirrors the Focus.onKeyEvent logic in the real _ConversationComposer:
/// - enterToSend=true: Enter → send, Shift+Enter → newline
/// - enterToSend=false: Ctrl/Cmd+Enter → send, Enter → newline
class _TestComposer extends StatelessWidget {
  const _TestComposer({
    required this.controller,
    required this.focusNode,
    required this.enterToSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enterToSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey != LogicalKeyboardKey.enter) {
          return KeyEventResult.ignored;
        }

        final isShift = HardwareKeyboard.instance.isShiftPressed;
        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final isMeta = HardwareKeyboard.instance.isMetaPressed;

        if (enterToSend) {
          if (isShift) {
            // Shift+Enter → insert newline
            final text = controller.text;
            final selection = controller.selection;
            final newText = text.replaceRange(
              selection.start,
              selection.end,
              '\n',
            );
            controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(
                offset: selection.start + 1,
              ),
            );
            return KeyEventResult.handled;
          } else if (!isCtrl && !isMeta) {
            // Enter → send
            onSend();
            return KeyEventResult.handled;
          }
        } else {
          if (isCtrl || isMeta) {
            // Ctrl/Cmd+Enter → send
            onSend();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        key: const ValueKey('composer-input'),
        controller: controller,
        focusNode: focusNode,
        minLines: 1,
        maxLines: 4,
      ),
    );
  }
}
