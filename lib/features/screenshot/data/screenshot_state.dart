import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';

/// Immutable state for the screenshot annotation editor.
@immutable
class ScreenshotState {
  const ScreenshotState({
    this.imagePath,
    this.annotations = const [],
    this.undoneAnnotations = const [],
    this.selectedTool = AnnotationTool.freehand,
    this.selectedColor = const Color(0xFFFF0000),
    this.isExporting = false,
    this.exportedPath,
  });

  /// Path to the captured screenshot image.
  final String? imagePath;

  /// The list of annotations drawn on the canvas.
  final List<Annotation> annotations;

  /// Annotations that were undone (for redo support).
  final List<Annotation> undoneAnnotations;

  /// The currently selected annotation tool.
  final AnnotationTool selectedTool;

  /// The currently selected annotation color.
  final Color selectedColor;

  /// Whether the annotated image is currently being exported.
  final bool isExporting;

  /// Path to the exported (flattened) annotated image, if available.
  final String? exportedPath;

  /// Whether there are annotations that can be undone.
  bool get canUndo => annotations.isNotEmpty;

  /// Whether there are undone annotations that can be redone.
  bool get canRedo => undoneAnnotations.isNotEmpty;

  ScreenshotState copyWith({
    String? imagePath,
    List<Annotation>? annotations,
    List<Annotation>? undoneAnnotations,
    AnnotationTool? selectedTool,
    Color? selectedColor,
    bool? isExporting,
    String? exportedPath,
    bool clearExportedPath = false,
  }) {
    return ScreenshotState(
      imagePath: imagePath ?? this.imagePath,
      annotations: annotations ?? this.annotations,
      undoneAnnotations: undoneAnnotations ?? this.undoneAnnotations,
      selectedTool: selectedTool ?? this.selectedTool,
      selectedColor: selectedColor ?? this.selectedColor,
      isExporting: isExporting ?? this.isExporting,
      exportedPath:
          clearExportedPath ? null : (exportedPath ?? this.exportedPath),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ScreenshotState &&
            runtimeType == other.runtimeType &&
            imagePath == other.imagePath &&
            listEquals(annotations, other.annotations) &&
            listEquals(undoneAnnotations, other.undoneAnnotations) &&
            selectedTool == other.selectedTool &&
            selectedColor == other.selectedColor &&
            isExporting == other.isExporting &&
            exportedPath == other.exportedPath;
  }

  @override
  int get hashCode => Object.hash(
        imagePath,
        Object.hashAll(annotations),
        Object.hashAll(undoneAnnotations),
        selectedTool,
        selectedColor,
        isExporting,
        exportedPath,
      );
}
