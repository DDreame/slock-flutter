import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/features/screenshot/application/screenshot_store.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';
import 'package:slock_app/features/screenshot/data/screenshot_capture_service.dart';
import 'package:slock_app/features/screenshot/data/screenshot_state.dart';
import 'package:slock_app/features/screenshot/presentation/widgets/annotation_canvas.dart';
import 'package:slock_app/features/screenshot/presentation/widgets/annotation_toolbar.dart';
import 'package:slock_app/features/share/application/share_intent_store.dart';
import 'package:slock_app/features/share/data/shared_content.dart';

/// Full-screen page for annotating a captured screenshot.
///
/// Displays the screenshot image with an interactive annotation canvas overlay.
/// The toolbar at the bottom provides tool selection, undo/redo, and colors.
/// Action buttons: share to channel/DM (via #408 share pipeline), discard.
class ScreenshotAnnotatePage extends ConsumerStatefulWidget {
  const ScreenshotAnnotatePage({super.key});

  @override
  ConsumerState<ScreenshotAnnotatePage> createState() =>
      _ScreenshotAnnotatePageState();
}

class _ScreenshotAnnotatePageState
    extends ConsumerState<ScreenshotAnnotatePage> {
  /// Currently in-progress freehand stroke (live feedback).
  FreehandAnnotation? _activeStroke;

  /// Start point for arrow tool.
  Offset? _arrowStart;

  /// End point for arrow tool (updated during drag).
  Offset? _arrowEnd;

  final _captureService = const ScreenshotCaptureService();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(screenshotStoreProvider);
    final store = ref.read(screenshotStoreProvider.notifier);

    if (state.imagePath == null) {
      return const Scaffold(
        body: Center(child: Text('No screenshot captured')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          key: const ValueKey('screenshot-discard'),
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            store.reset();
            Navigator.of(context).pop();
          },
          tooltip: 'Discard',
        ),
        title: const Text(
          'Annotate Screenshot',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            key: const ValueKey('screenshot-share'),
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: state.isExporting ? null : () => _onShare(store, state),
            tooltip: 'Share',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onPanStart: (details) =>
                  _onPanStart(details, state.selectedTool, state.selectedColor),
              onPanUpdate: (details) => _onPanUpdate(
                  details, state.selectedTool, state.selectedColor),
              onPanEnd: (details) =>
                  _onPanEnd(store, state.selectedTool, state.selectedColor),
              onTapUp: (details) => _onTapUp(
                details,
                store,
                state.selectedTool,
                state.selectedColor,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background: the captured screenshot.
                  Image.file(
                    File(state.imagePath!),
                    fit: BoxFit.contain,
                  ),
                  // Overlay: annotation canvas.
                  CustomPaint(
                    painter: AnnotationPainter(
                      annotations: state.annotations,
                      activeStroke: _activeStroke,
                    ),
                    size: Size.infinite,
                  ),
                  // Loading overlay during export.
                  if (state.isExporting)
                    const ColoredBox(
                      color: Colors.black54,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
          // Toolbar at the bottom.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: AnnotationToolbar(
                  selectedTool: state.selectedTool,
                  selectedColor: state.selectedColor,
                  canUndo: state.canUndo,
                  canRedo: state.canRedo,
                  onToolSelected: store.selectTool,
                  onColorSelected: store.selectColor,
                  onUndo: store.undo,
                  onRedo: store.redo,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPanStart(
    DragStartDetails details,
    AnnotationTool tool,
    Color color,
  ) {
    final pos = details.localPosition;
    switch (tool) {
      case AnnotationTool.freehand:
        setState(() {
          _activeStroke = FreehandAnnotation(
            color: color,
            points: [pos],
          );
        });
      case AnnotationTool.arrow:
        _arrowStart = pos;
      case AnnotationTool.text:
        break; // Text uses tap, not drag.
    }
  }

  void _onPanUpdate(
    DragUpdateDetails details,
    AnnotationTool tool,
    Color color,
  ) {
    final pos = details.localPosition;
    switch (tool) {
      case AnnotationTool.freehand:
        if (_activeStroke != null) {
          setState(() {
            _activeStroke = _activeStroke!.addPoint(pos);
          });
        }
      case AnnotationTool.arrow:
        _arrowEnd = pos;
      case AnnotationTool.text:
        break;
    }
  }

  void _onPanEnd(
    ScreenshotStore store,
    AnnotationTool tool,
    Color color,
  ) {
    switch (tool) {
      case AnnotationTool.freehand:
        if (_activeStroke != null && _activeStroke!.points.length >= 2) {
          store.addAnnotation(_activeStroke!);
        }
        setState(() {
          _activeStroke = null;
        });
      case AnnotationTool.arrow:
        if (_arrowStart != null && _arrowEnd != null) {
          store.addAnnotation(ArrowAnnotation(
            color: color,
            start: _arrowStart!,
            end: _arrowEnd!,
          ));
        }
        _arrowStart = null;
        _arrowEnd = null;
      case AnnotationTool.text:
        break;
    }
  }

  void _onTapUp(
    TapUpDetails details,
    ScreenshotStore store,
    AnnotationTool tool,
    Color color,
  ) {
    if (tool == AnnotationTool.text) {
      _showTextInputDialog(details.localPosition, store, color);
    }
  }

  Future<void> _showTextInputDialog(
    Offset position,
    ScreenshotStore store,
    Color color,
  ) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter text...'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (text != null && text.isNotEmpty) {
      store.addAnnotation(TextAnnotation(
        color: color,
        position: position,
        text: text,
      ));
    }
  }

  Future<void> _onShare(
    ScreenshotStore store,
    ScreenshotState state,
  ) async {
    store.setExporting(true);

    try {
      // If there are annotations, export a flattened image.
      // Otherwise, use the original screenshot directly.
      final String? exportedPath;
      if (state.annotations.isNotEmpty) {
        exportedPath = await _captureService.export(
          imagePath: state.imagePath!,
          annotations: state.annotations,
        );
      } else {
        exportedPath = state.imagePath;
      }

      if (exportedPath == null) {
        store.setExporting(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to export screenshot')),
          );
        }
        return;
      }

      store.setExportedPath(exportedPath);

      // Hand the exported image to the share pipeline (#408).
      // Create SharedContent with the image and feed it to the share intent
      // store, then navigate to /share-target.
      if (!mounted) return;

      final content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.image,
          path: exportedPath,
          mimeType: 'image/png',
        ),
      ]);
      ref.read(shareIntentStoreProvider.notifier).setContent(content);
      context.go('/share-target');
    } catch (e) {
      store.setExporting(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}
