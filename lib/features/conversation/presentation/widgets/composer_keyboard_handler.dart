import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Shared keyboard event handler for the message composer.
///
/// Extracted so both the production `_ConversationComposer` and tests
/// use the exact same logic — no divergence possible.
///
/// [onTextChanged] is called after Shift+Enter inserts a newline so the
/// caller can synchronize draft state. Without this, programmatic
/// `controller.value` mutations do not fire `TextField.onChanged`.
///
/// Behavior:
/// - [enterToSend]=true: Enter → send, Shift+Enter → newline
/// - [enterToSend]=false: Ctrl/Cmd+Enter → send, Enter → ignored
KeyEventResult handleComposerKeyEvent(
  FocusNode node,
  KeyEvent event, {
  required bool enterToSend,
  required TextEditingController controller,
  required bool canSend,
  required VoidCallback onSend,
  ValueChanged<String>? onTextChanged,
}) {
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
        selection: TextSelection.collapsed(offset: selection.start + 1),
      );
      // Notify draft state — programmatic controller mutations don't
      // fire TextField.onChanged, so we must sync explicitly.
      onTextChanged?.call(newText);
      return KeyEventResult.handled;
    } else if (!isCtrl && !isMeta) {
      // Enter → send
      if (canSend) onSend();
      return KeyEventResult.handled;
    }
  } else {
    if (isCtrl || isMeta) {
      // Ctrl/Cmd+Enter → send
      if (canSend) onSend();
      return KeyEventResult.handled;
    }
  }
  return KeyEventResult.ignored;
}
