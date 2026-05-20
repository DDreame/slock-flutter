import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Decodes image pixel dimensions from raw bytes while ensuring GPU resources
/// ([ui.Codec] + [ui.Image]) are properly disposed via try/finally.
///
/// Extracted from [ScreenshotAnnotatePage._loadImageSize] for testability
/// (#661 P0-2 GPU memory leak fix).
///
/// [onCodecDisposed] and [onImageDisposed] are test hooks that fire
/// immediately after the respective native resource is freed. Pass null
/// (default) in production.
Future<Size> decodeImageDimensions(
  Uint8List bytes, {
  @visibleForTesting VoidCallback? onCodecDisposed,
  @visibleForTesting VoidCallback? onImageDisposed,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      return Size(image.width.toDouble(), image.height.toDouble());
    } finally {
      image.dispose();
      onImageDisposed?.call();
    }
  } finally {
    codec.dispose();
    onCodecDisposed?.call();
  }
}
