import 'package:flutter/material.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Toolbar for the screenshot annotation editor.
///
/// Shows tool selection buttons, undo/redo, and a color picker.
class AnnotationToolbar extends StatelessWidget {
  const AnnotationToolbar({
    super.key,
    required this.selectedTool,
    required this.selectedColor,
    required this.canUndo,
    required this.canRedo,
    required this.onToolSelected,
    required this.onColorSelected,
    required this.onUndo,
    required this.onRedo,
  });

  final AnnotationTool selectedTool;
  final Color selectedColor;
  final bool canUndo;
  final bool canRedo;
  final ValueChanged<AnnotationTool> onToolSelected;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  static const _colors = <Color>[
    Color(0xFFFF0000), // Red
    Color(0xFF00FF00), // Green
    Color(0xFF0000FF), // Blue
    Color(0xFFFFFF00), // Yellow
    Color(0xFFFFFFFF), // White
    Color(0xFF000000), // Black
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorLabels = <Color, String>{
      const Color(0xFFFF0000): l10n.annotationColorRed,
      const Color(0xFF00FF00): l10n.annotationColorGreen,
      const Color(0xFF0000FF): l10n.annotationColorBlue,
      const Color(0xFFFFFF00): l10n.annotationColorYellow,
      const Color(0xFFFFFFFF): l10n.annotationColorWhite,
      const Color(0xFF000000): l10n.annotationColorBlack,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolButton(
            icon: Icons.brush,
            label: l10n.annotationDraw,
            isSelected: selectedTool == AnnotationTool.freehand,
            onTap: () => onToolSelected(AnnotationTool.freehand),
          ),
          _ToolButton(
            icon: Icons.text_fields,
            label: l10n.annotationText,
            isSelected: selectedTool == AnnotationTool.text,
            onTap: () => onToolSelected(AnnotationTool.text),
          ),
          _ToolButton(
            icon: Icons.arrow_forward,
            label: l10n.annotationArrow,
            isSelected: selectedTool == AnnotationTool.arrow,
            onTap: () => onToolSelected(AnnotationTool.arrow),
          ),
          const VerticalDivider(
            width: 16,
            thickness: 1,
            color: Colors.white24,
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            color: canUndo ? Colors.white : Colors.white38,
            onPressed: canUndo ? onUndo : null,
            tooltip: l10n.annotationUndo,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            color: canRedo ? Colors.white : Colors.white38,
            onPressed: canRedo ? onRedo : null,
            tooltip: l10n.annotationRedo,
          ),
          const VerticalDivider(
            width: 16,
            thickness: 1,
            color: Colors.white24,
          ),
          ..._colors.map((color) => _ColorDot(
                color: color,
                label: colorLabels[color] ?? '',
                isSelected: selectedColor == color,
                onTap: () => onColorSelected(color),
              )),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white24 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white38,
              width: isSelected ? 2.5 : 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
