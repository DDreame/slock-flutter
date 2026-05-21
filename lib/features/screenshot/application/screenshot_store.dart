import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';
import 'package:slock_app/features/screenshot/data/screenshot_state.dart';

final screenshotStoreProvider =
    NotifierProvider<ScreenshotStore, ScreenshotState>(ScreenshotStore.new);

/// Manages screenshot annotation state: tool selection, annotations,
/// undo/redo, and export lifecycle.
class ScreenshotStore extends Notifier<ScreenshotState> {
  @override
  ScreenshotState build() => const ScreenshotState();

  /// Sets the captured screenshot image path.
  void setCapturedImage(String path) {
    state = ScreenshotState(imagePath: path);
  }

  /// Selects the active annotation tool.
  void selectTool(AnnotationTool tool) {
    state = state.copyWith(selectedTool: tool);
  }

  /// Selects the active annotation color.
  void selectColor(Color color) {
    state = state.copyWith(selectedColor: color);
  }

  /// Adds a completed annotation to the canvas.
  /// Clears the redo stack (new action invalidates redo history).
  void addAnnotation(Annotation annotation) {
    state = state.copyWith(
      annotations: [...state.annotations, annotation],
      undoneAnnotations: const [],
    );
  }

  /// Replaces the last annotation (used for live-updating freehand strokes).
  void updateLastAnnotation(Annotation annotation) {
    if (state.annotations.isEmpty) {
      addAnnotation(annotation);
      return;
    }
    final updated = [...state.annotations];
    updated[updated.length - 1] = annotation;
    state = state.copyWith(annotations: updated);
  }

  /// Undoes the last annotation.
  void undo() {
    if (!state.canUndo) return;
    final annotations = [...state.annotations];
    final removed = annotations.removeLast();
    state = state.copyWith(
      annotations: annotations,
      undoneAnnotations: [...state.undoneAnnotations, removed],
    );
  }

  /// Redoes the last undone annotation.
  void redo() {
    if (!state.canRedo) return;
    final undone = [...state.undoneAnnotations];
    final restored = undone.removeLast();
    state = state.copyWith(
      annotations: [...state.annotations, restored],
      undoneAnnotations: undone,
    );
  }

  /// Marks the store as exporting (shows loading indicator).
  void setExporting(bool exporting) {
    state = state.copyWith(isExporting: exporting);
  }

  /// Sets the exported (flattened) image path after export completes.
  void setExportedPath(String path) {
    state = state.copyWith(exportedPath: path, isExporting: false);
  }

  /// Resets the store to initial state (e.g., after discard or share).
  ///
  /// Deletes referenced temp files (capture + export) to prevent orphaned
  /// PNG accumulation (#713).
  Future<void> reset() async {
    final paths = [state.imagePath, state.exportedPath];
    state = const ScreenshotState();

    for (final path in paths) {
      if (path == null) continue;
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Best-effort deletion; don't crash on I/O failure.
      }
    }
  }
}
