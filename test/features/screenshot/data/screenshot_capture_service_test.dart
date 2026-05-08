import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/screenshot/data/screenshot_capture_service.dart';

void main() {
  group('ScreenshotCaptureService', () {
    late ScreenshotCaptureService service;

    setUp(() {
      service = const ScreenshotCaptureService();
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
