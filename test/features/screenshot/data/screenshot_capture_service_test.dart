import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/screenshot/data/screenshot_capture_service.dart';

void main() {
  group('ScreenshotCaptureService', () {
    late ScreenshotCaptureService service;

    setUp(() {
      service = const ScreenshotCaptureService();
    });

    test('export disposes codec, base image, picture, and exported image',
        () async {
      final disposed = <String>[];
      service = ScreenshotCaptureService(
        onExportCodecDisposed: () => disposed.add('codec'),
        onExportBaseImageDisposed: () => disposed.add('baseImage'),
        onExportPictureDisposed: () => disposed.add('picture'),
        onExportedImageDisposed: () => disposed.add('exportedImage'),
      );
      final tempDir = Directory.systemTemp.createTempSync('screenshot_export_');
      final inputFile = File('${tempDir.path}/base.gif')
        ..writeAsBytesSync(_gif1x1());
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final path = await service.export(
        imagePath: inputFile.path,
        annotations: const [],
      );
      addTearDown(() {
        if (path != null) File(path).deleteSync();
      });

      expect(path, isNotNull);
      expect(disposed,
          containsAll(['codec', 'baseImage', 'picture', 'exportedImage']));
    });

    testWidgets('returns null when boundary key has no context',
        (tester) async {
      final orphanKey = GlobalKey();
      final path = await service.capture(orphanKey, pixelRatio: 1.0);
      expect(path, isNull);
    });

    testWidgets('returns null when render object is not RenderRepaintBoundary',
        (tester) async {
      final key = GlobalKey();
      // SizedBox creates a RenderConstrainedBox, not RenderRepaintBoundary.
      await tester.pumpWidget(SizedBox(key: key, width: 10, height: 10));

      final path = await service.capture(key, pixelRatio: 1.0);
      expect(path, isNull);
    });
  });
}

List<int> _gif1x1() => const [
      0x47,
      0x49,
      0x46,
      0x38,
      0x39,
      0x61,
      0x01,
      0x00,
      0x01,
      0x00,
      0x80,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0xFF,
      0xFF,
      0xFF,
      0x21,
      0xF9,
      0x04,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x2C,
      0x00,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x01,
      0x00,
      0x00,
      0x02,
      0x02,
      0x44,
      0x01,
      0x00,
      0x3B,
    ];
