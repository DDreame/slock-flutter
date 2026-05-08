import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';
import 'package:slock_app/features/screenshot/presentation/widgets/annotation_canvas.dart';

void main() {
  group('AnnotationPainter', () {
    test('shouldRepaint returns true when annotations change', () {
      const painter1 = AnnotationPainter(annotations: []);
      const painter2 = AnnotationPainter(annotations: [
        ArrowAnnotation(
          color: Color(0xFFFF0000),
          start: Offset.zero,
          end: Offset(10, 10),
        ),
      ]);

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns false when annotations are identical', () {
      const annotations = <Annotation>[
        ArrowAnnotation(
          color: Color(0xFFFF0000),
          start: Offset.zero,
          end: Offset(10, 10),
        ),
      ];
      const painter1 = AnnotationPainter(annotations: annotations);
      const painter2 = AnnotationPainter(annotations: annotations);

      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('shouldRepaint returns true when displayScale changes', () {
      const painter1 = AnnotationPainter(
        annotations: [],
        displayScale: 1.0,
        displayOffset: Offset.zero,
      );
      const painter2 = AnnotationPainter(
        annotations: [],
        displayScale: 2.0,
        displayOffset: Offset.zero,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when displayOffset changes', () {
      const painter1 = AnnotationPainter(
        annotations: [],
        displayScale: 1.0,
        displayOffset: Offset.zero,
      );
      const painter2 = AnnotationPainter(
        annotations: [],
        displayScale: 1.0,
        displayOffset: Offset(10, 20),
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when activeStroke changes', () {
      const painter1 = AnnotationPainter(
        annotations: [],
        activeStroke: null,
      );
      const painter2 = AnnotationPainter(
        annotations: [],
        activeStroke: FreehandAnnotation(
          color: Color(0xFFFF0000),
          points: [Offset.zero, Offset(5, 5)],
        ),
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    testWidgets('paints without error in display mode', (tester) async {
      await tester.pumpWidget(
        const CustomPaint(
          painter: AnnotationPainter(
            annotations: [
              FreehandAnnotation(
                color: Color(0xFFFF0000),
                points: [Offset(10, 10), Offset(50, 50), Offset(100, 30)],
              ),
              TextAnnotation(
                color: Color(0xFF0000FF),
                position: Offset(20, 20),
                text: 'Hello',
              ),
              ArrowAnnotation(
                color: Color(0xFF00FF00),
                start: Offset(0, 0),
                end: Offset(80, 80),
              ),
            ],
            displayScale: 0.5,
            displayOffset: Offset(10, 20),
          ),
          size: Size(200, 200),
        ),
      );

      // No error thrown — painter handles all annotation types with transform.
      expect(tester.takeException(), isNull);
    });

    testWidgets('paints without error in export mode (no transform)',
        (tester) async {
      await tester.pumpWidget(
        const CustomPaint(
          painter: AnnotationPainter(
            annotations: [
              FreehandAnnotation(
                color: Color(0xFFFF0000),
                points: [Offset(10, 10), Offset(50, 50)],
              ),
              ArrowAnnotation(
                color: Color(0xFF00FF00),
                start: Offset(0, 0),
                end: Offset(200, 200),
              ),
            ],
          ),
          size: Size(400, 400),
        ),
      );

      // No error thrown — painter handles annotations without transform.
      expect(tester.takeException(), isNull);
    });

    testWidgets('paints active stroke without transform', (tester) async {
      await tester.pumpWidget(
        const CustomPaint(
          painter: AnnotationPainter(
            annotations: [],
            activeStroke: FreehandAnnotation(
              color: Color(0xFFFF0000),
              points: [Offset(10, 10), Offset(50, 50), Offset(80, 20)],
            ),
            displayScale: 0.5,
            displayOffset: Offset(10, 20),
          ),
          size: Size(200, 200),
        ),
      );

      // Active stroke should paint in display coordinates (no transform).
      expect(tester.takeException(), isNull);
    });
  });

  group('Coordinate transform logic', () {
    // These tests verify the math used in ScreenshotAnnotatePage for
    // converting between display and image coordinate spaces.

    test('BoxFit.contain transform — landscape image in square container', () {
      const imageSize = Size(1000, 500);
      const containerSize = Size(400, 400);

      final fitted = applyBoxFit(BoxFit.contain, imageSize, containerSize);
      final scale = fitted.destination.width / fitted.source.width;
      final offsetX = (containerSize.width - fitted.destination.width) / 2;
      final offsetY = (containerSize.height - fitted.destination.height) / 2;

      // 1000×500 into 400×400: scale = 400/1000 = 0.4
      // Display size: 400×200, offset: (0, 100)
      expect(scale, closeTo(0.4, 0.001));
      expect(offsetX, closeTo(0.0, 0.001));
      expect(offsetY, closeTo(100.0, 0.001));

      // Display→image: gesture at (200, 200) → image (200/0.4, (200-100)/0.4)
      const displayPos = Offset(200, 200);
      final imagePos = Offset(
        (displayPos.dx - offsetX) / scale,
        (displayPos.dy - offsetY) / scale,
      );
      expect(imagePos.dx, closeTo(500, 0.1));
      expect(imagePos.dy, closeTo(250, 0.1));
    });

    test('BoxFit.contain transform — portrait image in wide container', () {
      const imageSize = Size(500, 1000);
      const containerSize = Size(400, 400);

      final fitted = applyBoxFit(BoxFit.contain, imageSize, containerSize);
      final scale = fitted.destination.width / fitted.source.width;
      final offsetX = (containerSize.width - fitted.destination.width) / 2;
      final offsetY = (containerSize.height - fitted.destination.height) / 2;

      // 500×1000 into 400×400: scale = 400/1000 = 0.4
      // Display size: 200×400, offset: (100, 0)
      expect(scale, closeTo(0.4, 0.001));
      expect(offsetX, closeTo(100.0, 0.001));
      expect(offsetY, closeTo(0.0, 0.001));
    });

    test('BoxFit.contain transform — DPR 2x image in logical container', () {
      // Simulates a 2x DPR capture: 800px image in 400 logical container.
      const imageSize = Size(800, 1200);
      const containerSize = Size(400, 600);

      final fitted = applyBoxFit(BoxFit.contain, imageSize, containerSize);
      final scale = fitted.destination.width / fitted.source.width;
      final offsetX = (containerSize.width - fitted.destination.width) / 2;
      final offsetY = (containerSize.height - fitted.destination.height) / 2;

      // 800×1200 into 400×600: scale = min(400/800, 600/1200) = 0.5
      // Display fills container exactly (same aspect ratio).
      expect(scale, closeTo(0.5, 0.001));
      expect(offsetX, closeTo(0.0, 0.001));
      expect(offsetY, closeTo(0.0, 0.001));

      // A gesture at center (200, 300) maps to image (400, 600).
      const displayCenter = Offset(200, 300);
      final imageCenter = Offset(
        (displayCenter.dx - offsetX) / scale,
        (displayCenter.dy - offsetY) / scale,
      );
      expect(imageCenter.dx, closeTo(400, 0.1));
      expect(imageCenter.dy, closeTo(600, 0.1));
    });

    test('round-trip: display→image→display preserves coordinates', () {
      const imageSize = Size(1000, 800);
      const containerSize = Size(300, 500);

      final fitted = applyBoxFit(BoxFit.contain, imageSize, containerSize);
      final scale = fitted.destination.width / fitted.source.width;
      final offsetX = (containerSize.width - fitted.destination.width) / 2;
      final offsetY = (containerSize.height - fitted.destination.height) / 2;
      final offset = Offset(offsetX, offsetY);

      const displayPos = Offset(150, 250);

      // Display → image
      final imagePos = Offset(
        (displayPos.dx - offset.dx) / scale,
        (displayPos.dy - offset.dy) / scale,
      );

      // Image → display
      final roundTrip = Offset(
        imagePos.dx * scale + offset.dx,
        imagePos.dy * scale + offset.dy,
      );

      expect(roundTrip.dx, closeTo(displayPos.dx, 0.001));
      expect(roundTrip.dy, closeTo(displayPos.dy, 0.001));
    });
  });
}
