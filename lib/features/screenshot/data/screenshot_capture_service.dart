import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures the content of a [RepaintBoundary] as a PNG image file.
///
/// Uses [RenderRepaintBoundary.toImage] — no external packages required.
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
}
