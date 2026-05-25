import 'package:flutter/material.dart';

import 'package:slock_app/l10n/l10n.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

/// Supported markdown formatting actions.
enum MarkdownFormat {
  bold,
  italic,
  inlineCode,
  codeBlock,
  link,
}

/// Applies the given [format] to [controller]'s current text.
///
/// If text is selected, wraps the selection with the appropriate markers.
/// If the cursor is collapsed (no selection), inserts a placeholder with
/// the placeholder word pre-selected for easy overwrite.
void applyMarkdownFormat(
  TextEditingController controller,
  MarkdownFormat format,
) {
  final text = controller.value.text;
  var selection = controller.value.selection;

  // When the controller has never been focused, the selection is invalid
  // (base/extent == -1). Establish a sane collapsed cursor so toolbar
  // taps work on first use.
  if (!selection.isValid) {
    selection = TextSelection.collapsed(offset: text.length);
    controller.selection = selection;
  }

  final hasSelection = selection.baseOffset != selection.extentOffset;

  switch (format) {
    case MarkdownFormat.bold:
      _applyWrap(controller, text, selection, hasSelection,
          prefix: '**', suffix: '**', placeholder: 'bold');
    case MarkdownFormat.italic:
      _applyWrap(controller, text, selection, hasSelection,
          prefix: '*', suffix: '*', placeholder: 'italic');
    case MarkdownFormat.inlineCode:
      _applyWrap(controller, text, selection, hasSelection,
          prefix: '`', suffix: '`', placeholder: 'code');
    case MarkdownFormat.codeBlock:
      _applyCodeBlock(controller, text, selection, hasSelection);
    case MarkdownFormat.link:
      _applyLink(controller, text, selection, hasSelection);
  }
}

void _applyWrap(
  TextEditingController controller,
  String text,
  TextSelection selection,
  bool hasSelection, {
  required String prefix,
  required String suffix,
  required String placeholder,
}) {
  if (hasSelection) {
    final selected = text.substring(selection.start, selection.end);
    final replacement = '$prefix$selected$suffix';
    final newText =
        text.replaceRange(selection.start, selection.end, replacement);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + prefix.length + selected.length,
      ),
    );
  } else {
    final insertion = '$prefix$placeholder$suffix';
    final newText =
        text.replaceRange(selection.start, selection.start, insertion);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.start + prefix.length + placeholder.length,
      ),
    );
  }
}

void _applyCodeBlock(
  TextEditingController controller,
  String text,
  TextSelection selection,
  bool hasSelection,
) {
  if (hasSelection) {
    final selected = text.substring(selection.start, selection.end);
    final replacement = '```\n$selected\n```';
    final newText =
        text.replaceRange(selection.start, selection.end, replacement);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + 4 + selected.length,
      ),
    );
  } else {
    const placeholder = 'code';
    const insertion = '```\n$placeholder\n```';
    final newText =
        text.replaceRange(selection.start, selection.start, insertion);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: selection.start + 4,
        extentOffset: selection.start + 4 + placeholder.length,
      ),
    );
  }
}

void _applyLink(
  TextEditingController controller,
  String text,
  TextSelection selection,
  bool hasSelection,
) {
  if (hasSelection) {
    final selected = text.substring(selection.start, selection.end);
    final replacement = '[$selected](url)';
    final newText =
        text.replaceRange(selection.start, selection.end, replacement);
    // Select 'url' placeholder for easy overwrite.
    final urlStart = selection.start + 1 + selected.length + 2;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: urlStart,
        extentOffset: urlStart + 3,
      ),
    );
  } else {
    const insertion = '[text](url)';
    final newText =
        text.replaceRange(selection.start, selection.start, insertion);
    // Select 'url' placeholder for easy overwrite.
    final urlStart = selection.start + 7;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: urlStart,
        extentOffset: urlStart + 3,
      ),
    );
  }
}

/// A toolbar that provides markdown formatting shortcuts above the composer.
///
/// Toggle visibility with [visible]. When visible, displays a row of icon
/// buttons for bold, italic, inline code, code block, and link insertion.
class FormattingToolbar extends StatelessWidget {
  const FormattingToolbar({
    super.key,
    required this.controller,
    required this.visible,
    required this.focusNode,
    this.onChanged,
  });

  /// The text editing controller to apply formatting to.
  final TextEditingController controller;

  /// Whether the toolbar is currently visible.
  final bool visible;

  /// The focus node to re-focus after applying formatting.
  final FocusNode focusNode;

  /// Called with the new text after a format is applied, so the caller
  /// can sync draft state.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return Container(
      key: const ValueKey('formatting-toolbar'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        border: Border(
          bottom: BorderSide(color: colors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _ToolbarButton(
            key: const ValueKey('toolbar-bold'),
            icon: Icons.format_bold,
            tooltip: context.l10n.conversationFormatBold,
            onTap: () => _apply(MarkdownFormat.bold),
          ),
          _ToolbarButton(
            key: const ValueKey('toolbar-italic'),
            icon: Icons.format_italic,
            tooltip: context.l10n.conversationFormatItalic,
            onTap: () => _apply(MarkdownFormat.italic),
          ),
          _ToolbarButton(
            key: const ValueKey('toolbar-code'),
            icon: Icons.code,
            tooltip: context.l10n.conversationFormatInlineCode,
            onTap: () => _apply(MarkdownFormat.inlineCode),
          ),
          _ToolbarButton(
            key: const ValueKey('toolbar-codeblock'),
            icon: Icons.integration_instructions,
            tooltip: context.l10n.conversationFormatCodeBlock,
            onTap: () => _apply(MarkdownFormat.codeBlock),
          ),
          _ToolbarButton(
            key: const ValueKey('toolbar-link'),
            icon: Icons.link,
            tooltip: context.l10n.conversationFormatLink,
            onTap: () => _apply(MarkdownFormat.link),
          ),
        ],
      ),
    );
  }

  void _apply(MarkdownFormat format) {
    applyMarkdownFormat(controller, format);
    onChanged?.call(controller.text);
    focusNode.requestFocus();
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: ValueKey('$tooltip-ink'),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(icon, size: 20, color: colors.textSecondary),
        ),
      ),
    );
  }
}
