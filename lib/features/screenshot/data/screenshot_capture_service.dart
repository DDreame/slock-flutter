import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';
import 'package:slock_app/features/screenshot/presentation/widgets/annotation_canvas.dart';

/// Captures and exports screenshot images with annotation overlays.
///
/// Uses [RenderRepaintBoundary.toImage] for capture and [Canvas] + [Picture]
/// for exporting annotated images — no external packages required.
class ScreenshotCaptureService {
  const ScreenshotCaptureService();

  /// Captures the widget tree under [boundaryKey] and saves it as a PNG
  /// in the system temp directory.
  ///
  /// Returns the absolute path to the saved file, or `null` if the boundary
  /// cannot be found or has not been laid out yet.
  ///
  /// [pixelRatio] controls the output resolution (1.0 = logical pixels,
  /// 2.0 = 2x retina, etc.). Defaults to the device pixel ratio.
  Future<String?> capture(
    GlobalKey boundaryKey, {
    double pixelRatio = 1.0,
  }) async {
    final renderObject = boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;

    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(
      '${Directory.systemTemp.path}/screenshot_$timestamp.png',
    );
    await file.writeAsBytes(byteData.buffer.asUint8List());

    return file.path;
  }

  /// Exports a screenshot with annotations flattened onto it as a new PNG.
  ///
  /// Loads the base [imagePath], draws all [annotations] on top using the
  /// same [AnnotationPainter] rendering logic, and writes the result to a
  /// new temp file.
  ///
  /// Returns the path to the exported file, or `null` if the image cannot
  /// be loaded.
  Future<String?> export({
    required String imagePath,
    required List<Annotation> annotations,
  }) async {
    // Load the base image.
    final file = File(imagePath);
    if (!file.existsSync()) return null;

    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final baseImage = frame.image;

    final width = baseImage.width.toDouble();
    final height = baseImage.height.toDouble();

    // Create a picture recorder to draw the composite image.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw the base screenshot.
    canvas.drawImage(baseImage, Offset.zero, Paint());

    // Draw annotations on top.
    final painter = AnnotationPainter(annotations: annotations);
    painter.paint(canvas, Size(width, height));

    // Convert to image.
    final picture = recorder.endRecording();
    final exportedImage = await picture.toImage(width.toInt(), height.toInt());
    final exportedBytes =
        await exportedImage.toByteData(format: ui.ImageByteFormat.png);
    if (exportedBytes == null) return null;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final exportedFile = File(
      '${Directory.systemTemp.path}/screenshot_annotated_$timestamp.png',
    );
    await exportedFile.writeAsBytes(exportedBytes.buffer.asUint8List());

    return exportedFile.path;
  }
}
