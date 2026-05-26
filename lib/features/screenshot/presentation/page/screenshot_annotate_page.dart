import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/screenshot/application/screenshot_store.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';
import 'package:slock_app/features/screenshot/data/image_dimensions_decoder.dart';
import 'package:slock_app/features/screenshot/data/screenshot_capture_service.dart';
import 'package:slock_app/features/screenshot/data/screenshot_state.dart';
import 'package:slock_app/features/screenshot/presentation/widgets/annotation_canvas.dart';
import 'package:slock_app/features/screenshot/presentation/widgets/annotation_toolbar.dart';
import 'package:slock_app/features/share/application/share_intent_store.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Full-screen page for annotating a captured screenshot.
///
/// Displays the screenshot image with an interactive annotation canvas overlay.
/// The toolbar at the bottom provides tool selection, undo/redo, and colors.
/// Action buttons: share to channel/DM (via #408 share pipeline), save to
/// device (via system share sheet), discard.
///
/// ## Coordinate contract
///
/// All committed annotations are stored in **image-pixel** coordinates.
/// Sizes (strokeWidth, fontSize) are also normalized to image-pixel space
/// so the exported PNG matches what the user sees on screen.
///
/// The display transform (`scale`, `offset`) maps image→display coordinates.
/// [AnnotationPainter] applies this transform when rendering to the screen.
/// During export, annotations are painted at their native image-pixel
/// coordinates with no transform applied.
class ScreenshotAnnotatePage extends ConsumerStatefulWidget {
  const ScreenshotAnnotatePage({super.key});

  @override
  ConsumerState<ScreenshotAnnotatePage> createState() =>
      _ScreenshotAnnotatePageState();
}

class _ScreenshotAnnotatePageState
    extends ConsumerState<ScreenshotAnnotatePage> {
  /// Currently in-progress freehand stroke (live feedback in display coords).
  FreehandAnnotation? _activeStroke;

  /// Start point for arrow tool (in display coordinates during drag).
  Offset? _arrowStart;

  /// End point for arrow tool (in display coordinates during drag).
  Offset? _arrowEnd;

  final _captureService = const ScreenshotCaptureService();

  /// Intrinsic pixel dimensions of the base screenshot image.
  /// Null until the image header has been decoded.
  /// Editing is disabled while this is null (BLOCKER 2 guard).
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    // Load image dimensions once after first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadImageSize();
    });
  }

  /// Decodes the base image to obtain its pixel dimensions.
  Future<void> _loadImageSize() async {
    final imagePath = ref.read(screenshotStoreProvider).imagePath;
    if (imagePath == null) return;

    final file = File(imagePath);
    if (!file.existsSync()) return;

    final bytes = await file.readAsBytes();
    final size = await decodeImageDimensions(bytes);

    if (mounted) {
      setState(() {
        _imageSize = size;
      });
    }
  }

  /// Whether the image transform is ready and editing is enabled.
  bool get _isTransformReady => _imageSize != null;

  /// Computes the scale and offset for the `BoxFit.contain` layout of the
  /// image within the given [containerSize].
  ///
  /// Returns `(scale, offset)` where:
  /// - `scale` is the ratio from image-pixel to display-logical coordinates
  /// - `offset` is the top-left corner of the displayed image within the
  ///   container (accounts for letterboxing)
  ///
  /// Requires [_imageSize] to be non-null.
  (double scale, Offset offset) _computeDisplayTransform(Size containerSize) {
    final imgSize = _imageSize!;
    final fitted = applyBoxFit(BoxFit.contain, imgSize, containerSize);
    final scale = fitted.destination.width / fitted.source.width;
    final offsetX = (containerSize.width - fitted.destination.width) / 2;
    final offsetY = (containerSize.height - fitted.destination.height) / 2;
    return (scale, Offset(offsetX, offsetY));
  }

  /// Converts a gesture position in display-local coordinates to image-pixel
  /// coordinates using the current display transform.
  Offset _displayToImage(Offset displayPos, double scale, Offset offset) {
    return Offset(
      (displayPos.dx - offset.dx) / scale,
      (displayPos.dy - offset.dy) / scale,
    );
  }

  /// Converts a size value (strokeWidth, fontSize) from display-logical
  /// units to image-pixel units.
  double _displaySizeToImage(double displaySize, double scale) {
    return displaySize / scale;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(screenshotStoreProvider);
    final store = ref.read(screenshotStoreProvider.notifier);

    if (state.imagePath == null) {
      return Scaffold(
        body: Center(child: Text(context.l10n.screenshotAnnotateNoCapture)),
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
          tooltip: context.l10n.screenshotAnnotateDiscardTooltip,
        ),
        title: Text(
          context.l10n.screenshotAnnotateTitle,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            key: const ValueKey('screenshot-save'),
            icon: const Icon(Icons.save_alt, color: Colors.white),
            onPressed: state.isExporting ? null : () => _onSave(store, state),
            tooltip: context.l10n.screenshotAnnotateSaveTooltip,
          ),
          IconButton(
            key: const ValueKey('screenshot-share'),
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: state.isExporting ? null : () => _onShare(store, state),
            tooltip: context.l10n.screenshotAnnotateShareTooltip,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final containerSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );

                // Compute transform only when image dimensions are known.
                final double scale;
                final Offset offset;
                if (_isTransformReady) {
                  (scale, offset) = _computeDisplayTransform(containerSize);
                } else {
                  scale = 1.0;
                  offset = Offset.zero;
                }

                return Semantics(
                  key: const ValueKey('screenshot-canvas'),
                  label: context.l10n.screenshotCanvasSemantics,
                  child: GestureDetector(
                    // Disable gesture input until transform is ready to prevent
                    // misplaced annotations from identity-transform fallback.
                    onPanStart: _isTransformReady
                        ? (details) => _onPanStart(
                              details,
                              state.selectedTool,
                              state.selectedColor,
                              scale,
                              offset,
                            )
                        : null,
                    onPanUpdate: _isTransformReady
                        ? (details) => _onPanUpdate(
                              details,
                              state.selectedTool,
                              state.selectedColor,
                              scale,
                              offset,
                            )
                        : null,
                    onPanEnd: _isTransformReady
                        ? (details) => _onPanEnd(
                              store,
                              state.selectedTool,
                              state.selectedColor,
                              scale,
                              offset,
                            )
                        : null,
                    onTapUp: _isTransformReady
                        ? (details) => _onTapUp(
                              details,
                              store,
                              state.selectedTool,
                              state.selectedColor,
                              scale,
                              offset,
                            )
                        : null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background: the captured screenshot.
                        Image.file(
                          File(state.imagePath!),
                          fit: BoxFit.contain,
                        ),
                        // Overlay: annotation canvas.
                        if (_isTransformReady)
                          CustomPaint(
                            painter: AnnotationPainter(
                              annotations: state.annotations,
                              activeStroke: _activeStroke,
                              displayScale: scale,
                              displayOffset: offset,
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
                );
              },
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

  // ---------------------------------------------------------------------------
  // Gesture handlers
  // ---------------------------------------------------------------------------

  void _onPanStart(
    DragStartDetails details,
    AnnotationTool tool,
    Color color,
    double scale,
    Offset offset,
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
    double scale,
    Offset offset,
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
    double scale,
    Offset offset,
  ) {
    switch (tool) {
      case AnnotationTool.freehand:
        if (_activeStroke != null && _activeStroke!.points.length >= 2) {
          // Convert all display-coordinate points to image-pixel coordinates.
          // Also normalize strokeWidth to image space so the committed stroke
          // renders at the same visual size as the live preview.
          final imagePoints = _activeStroke!.points
              .map((p) => _displayToImage(p, scale, offset))
              .toList();
          store.addAnnotation(FreehandAnnotation(
            color: color,
            points: imagePoints,
            strokeWidth: _displaySizeToImage(_activeStroke!.strokeWidth, scale),
          ));
        }
        setState(() {
          _activeStroke = null;
        });
      case AnnotationTool.arrow:
        if (_arrowStart != null && _arrowEnd != null) {
          // Normalize positions and strokeWidth to image space.
          const defaultStrokeWidth = 3.0;
          store.addAnnotation(ArrowAnnotation(
            color: color,
            start: _displayToImage(_arrowStart!, scale, offset),
            end: _displayToImage(_arrowEnd!, scale, offset),
            strokeWidth: _displaySizeToImage(defaultStrokeWidth, scale),
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
    double scale,
    Offset offset,
  ) {
    if (tool == AnnotationTool.text) {
      _showTextInputDialog(
        details.localPosition,
        store,
        color,
        scale,
        offset,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Text input dialog
  // ---------------------------------------------------------------------------

  Future<void> _showTextInputDialog(
    Offset displayPosition,
    ScreenshotStore store,
    Color color,
    double scale,
    Offset offset,
  ) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(dialogCtx.l10n.screenshotAnnotateAddTextTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: dialogCtx.l10n.screenshotAnnotateTextHint,
          ),
          onSubmitted: (value) => Navigator.of(dialogCtx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(dialogCtx.l10n.screenshotAnnotateCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(controller.text),
            child: Text(dialogCtx.l10n.screenshotAnnotateAddButton),
          ),
        ],
      ),
    );
    controller.dispose();

    if (text != null && text.isNotEmpty) {
      // Normalize position and fontSize to image-pixel space.
      const defaultFontSize = 16.0;
      store.addAnnotation(TextAnnotation(
        color: color,
        position: _displayToImage(displayPosition, scale, offset),
        text: text,
        fontSize: _displaySizeToImage(defaultFontSize, scale),
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Export helper — produces the flattened PNG (annotations baked in).
  // ---------------------------------------------------------------------------

  /// Exports the screenshot with annotations flattened and returns the path,
  /// or null on failure. Sets isExporting on the store during the operation.
  Future<String?> _exportImage(
    ScreenshotStore store,
    ScreenshotState state,
  ) async {
    store.setExporting(true);

    try {
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
            SnackBar(
                content: Text(context.l10n.screenshotAnnotateExportFailed)),
          );
        }
        return null;
      }

      store.setExportedPath(exportedPath);
      return exportedPath;
    } on Exception catch (e) {
      ref.read(diagnosticsCollectorProvider).error(
            'ScreenshotAnnotate',
            'Export failed: $e',
          );
      store.setExporting(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.l10n.screenshotAnnotateExportError(e.toString())),
          ),
        );
      }
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Save to device (via system share sheet)
  // ---------------------------------------------------------------------------

  Future<void> _onSave(
    ScreenshotStore store,
    ScreenshotState state,
  ) async {
    final exportedPath = await _exportImage(store, state);
    if (exportedPath == null || !mounted) return;

    try {
      await Share.shareXFiles(
        [XFile(exportedPath)],
        subject: context.l10n.screenshotAnnotateShareSubject,
      );
    } on Exception catch (e) {
      ref.read(diagnosticsCollectorProvider).error(
            'ScreenshotAnnotate',
            'Save/share failed: $e',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.l10n.screenshotAnnotateSaveFailed(e.toString())),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Share to Slock channel/DM (via #408 share pipeline)
  // ---------------------------------------------------------------------------

  Future<void> _onShare(
    ScreenshotStore store,
    ScreenshotState state,
  ) async {
    final exportedPath = await _exportImage(store, state);
    if (exportedPath == null || !mounted) return;

    // Hand the exported image to the share pipeline (#408).
    final content = SharedContent(items: [
      SharedContentItem(
        type: SharedContentType.image,
        path: exportedPath,
        mimeType: 'image/png',
      ),
    ]);
    ref.read(shareIntentStoreProvider.notifier).setContent(content);
    // Push instead of go to preserve the originating conversation in the
    // back stack. context.go() drops the screenshot source page.
    context.push('/share-target');
  }
}
