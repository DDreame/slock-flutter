// =============================================================================
// #661 — P0-2 GPU Memory Leak Fix
//
// Invariants verified:
// INV-GPU-DISPOSE-1: decodeImageDimensions() disposes both the ui.Codec and
//                     ui.Image after extracting dimensions (try/finally).
// INV-GPU-DISPOSE-2: dispose order is image first, then codec.
// =============================================================================

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/screenshot/data/image_dimensions_decoder.dart';

/// Generates a valid PNG byte buffer using Flutter's native image encoding.
/// Guaranteed to be decodable by [ui.instantiateImageCodec] since it's
/// produced by the same engine.
Future<Uint8List> _generateValidPng({int width = 2, int height = 2}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFFF0000), BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return byteData!.buffer.asUint8List();
}

void main() {
  group('INV-GPU-DISPOSE: decodeImageDimensions disposes native resources', () {
    testWidgets(
      'INV-GPU-DISPOSE-1: both codec.dispose() and image.dispose() fire '
      'on successful decode',
      (tester) async {
        final pngBytes = await tester.runAsync(() => _generateValidPng());
        expect(pngBytes, isNotNull, reason: 'PNG generation must succeed');

        var codecDisposed = false;
        var imageDisposed = false;

        final size = await tester.runAsync(
          () => decodeImageDimensions(
            pngBytes!,
            onCodecDisposed: () => codecDisposed = true,
            onImageDisposed: () => imageDisposed = true,
          ),
        );

        expect(size, isNotNull, reason: 'decode must succeed');
        expect(size!.width, 2.0);
        expect(size.height, 2.0);
        expect(
          imageDisposed,
          isTrue,
          reason: 'image.dispose() must fire after dimension extraction '
              '(INV-GPU-DISPOSE-1)',
        );
        expect(
          codecDisposed,
          isTrue,
          reason: 'codec.dispose() must fire after dimension extraction '
              '(INV-GPU-DISPOSE-1)',
        );
      },
    );

    testWidgets(
      'INV-GPU-DISPOSE-2: dispose order is image first, then codec',
      (tester) async {
        final pngBytes = await tester.runAsync(() => _generateValidPng());
        expect(pngBytes, isNotNull, reason: 'PNG generation must succeed');

        final disposeOrder = <String>[];

        await tester.runAsync(
          () => decodeImageDimensions(
            pngBytes!,
            onCodecDisposed: () => disposeOrder.add('codec'),
            onImageDisposed: () => disposeOrder.add('image'),
          ),
        );

        expect(
          disposeOrder,
          ['image', 'codec'],
          reason: 'Image must be disposed before its parent codec '
              '(INV-GPU-DISPOSE-2)',
        );
      },
    );
  });
}
