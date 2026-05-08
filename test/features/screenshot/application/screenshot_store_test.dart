import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/screenshot/application/screenshot_store.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';
import 'package:slock_app/features/screenshot/data/screenshot_state.dart';

void main() {
  late ProviderContainer container;
  late ScreenshotStore store;

  setUp(() {
    container = ProviderContainer();
    store = container.read(screenshotStoreProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  ScreenshotState readState() => container.read(screenshotStoreProvider);

  group('ScreenshotStore', () {
    test('initial state has no image and defaults', () {
      final s = readState();
      expect(s.imagePath, isNull);
      expect(s.annotations, isEmpty);
      expect(s.undoneAnnotations, isEmpty);
      expect(s.selectedTool, AnnotationTool.freehand);
      expect(s.selectedColor, const Color(0xFFFF0000));
      expect(s.isExporting, isFalse);
      expect(s.exportedPath, isNull);
      expect(s.canUndo, isFalse);
      expect(s.canRedo, isFalse);
    });

    test('setCapturedImage sets path and resets state', () {
      store.addAnnotation(const FreehandAnnotation(
        color: Color(0xFFFF0000),
        points: [Offset.zero],
      ));
      store.setCapturedImage('/tmp/screenshot.png');

      expect(readState().imagePath, '/tmp/screenshot.png');
      expect(readState().annotations, isEmpty);
    });

    test('selectTool changes the active tool', () {
      store.selectTool(AnnotationTool.text);
      expect(readState().selectedTool, AnnotationTool.text);

      store.selectTool(AnnotationTool.arrow);
      expect(readState().selectedTool, AnnotationTool.arrow);
    });

    test('selectColor changes the active color', () {
      store.selectColor(const Color(0xFF00FF00));
      expect(readState().selectedColor, const Color(0xFF00FF00));
    });

    test('addAnnotation appends to list and clears redo stack', () {
      const a1 = FreehandAnnotation(
        color: Color(0xFFFF0000),
        points: [Offset.zero, Offset(10, 10)],
      );
      const a2 = TextAnnotation(
        color: Color(0xFF0000FF),
        position: Offset(50, 50),
        text: 'Hello',
      );

      store.addAnnotation(a1);
      expect(readState().annotations, [a1]);
      expect(readState().canUndo, isTrue);

      store.addAnnotation(a2);
      expect(readState().annotations, [a1, a2]);
    });

    test('addAnnotation clears redo stack', () {
      const a1 = FreehandAnnotation(
        color: Color(0xFFFF0000),
        points: [Offset.zero],
      );
      const a2 = FreehandAnnotation(
        color: Color(0xFF00FF00),
        points: [Offset(1, 1)],
      );

      store.addAnnotation(a1);
      store.undo();
      expect(readState().canRedo, isTrue);

      store.addAnnotation(a2);
      expect(readState().canRedo, isFalse);
      expect(readState().annotations, [a2]);
    });

    test('updateLastAnnotation replaces the last annotation', () {
      const a1 = FreehandAnnotation(
        color: Color(0xFFFF0000),
        points: [Offset.zero],
      );
      final a1Updated = a1.addPoint(const Offset(10, 10));

      store.addAnnotation(a1);
      store.updateLastAnnotation(a1Updated);

      expect(readState().annotations.length, 1);
      expect(
        (readState().annotations.first as FreehandAnnotation).points.length,
        2,
      );
    });

    test('updateLastAnnotation adds if list is empty', () {
      const a1 = FreehandAnnotation(
        color: Color(0xFFFF0000),
        points: [Offset.zero],
      );

      store.updateLastAnnotation(a1);
      expect(readState().annotations, [a1]);
    });

    group('undo/redo', () {
      test('undo removes last annotation and adds to redo stack', () {
        const a1 = FreehandAnnotation(
          color: Color(0xFFFF0000),
          points: [Offset.zero],
        );
        const a2 = TextAnnotation(
          color: Color(0xFF0000FF),
          position: Offset(50, 50),
          text: 'Test',
        );

        store.addAnnotation(a1);
        store.addAnnotation(a2);
        store.undo();

        expect(readState().annotations, [a1]);
        expect(readState().undoneAnnotations.length, 1);
        expect(readState().canRedo, isTrue);
      });

      test('redo restores last undone annotation', () {
        const a1 = FreehandAnnotation(
          color: Color(0xFFFF0000),
          points: [Offset.zero],
        );

        store.addAnnotation(a1);
        store.undo();
        expect(readState().annotations, isEmpty);

        store.redo();
        expect(readState().annotations, [a1]);
        expect(readState().canRedo, isFalse);
      });

      test('multiple undo/redo preserves order', () {
        const a1 = FreehandAnnotation(
          color: Color(0xFFFF0000),
          points: [Offset.zero],
        );
        const a2 = TextAnnotation(
          color: Color(0xFF0000FF),
          position: Offset(10, 10),
          text: 'A',
        );
        const a3 = ArrowAnnotation(
          color: Color(0xFF00FF00),
          start: Offset.zero,
          end: Offset(100, 100),
        );

        store.addAnnotation(a1);
        store.addAnnotation(a2);
        store.addAnnotation(a3);

        store.undo(); // removes a3
        store.undo(); // removes a2
        expect(readState().annotations, [a1]);

        store.redo(); // restores a2
        expect(readState().annotations, [a1, a2]);

        store.redo(); // restores a3
        expect(readState().annotations, [a1, a2, a3]);
      });

      test('undo on empty list is a no-op', () {
        store.undo();
        expect(readState().annotations, isEmpty);
        expect(readState().undoneAnnotations, isEmpty);
      });

      test('redo on empty redo stack is a no-op', () {
        store.redo();
        expect(readState().annotations, isEmpty);
      });
    });

    test('setExporting updates flag', () {
      store.setExporting(true);
      expect(readState().isExporting, isTrue);

      store.setExporting(false);
      expect(readState().isExporting, isFalse);
    });

    test('setExportedPath sets path and clears exporting flag', () {
      store.setExporting(true);
      store.setExportedPath('/tmp/annotated.png');

      expect(readState().exportedPath, '/tmp/annotated.png');
      expect(readState().isExporting, isFalse);
    });

    test('reset returns to initial state', () {
      store.setCapturedImage('/tmp/test.png');
      store.addAnnotation(const FreehandAnnotation(
        color: Color(0xFFFF0000),
        points: [Offset.zero],
      ));
      store.selectTool(AnnotationTool.text);
      store.setExportedPath('/tmp/exported.png');

      store.reset();

      expect(readState().imagePath, isNull);
      expect(readState().annotations, isEmpty);
      expect(readState().selectedTool, AnnotationTool.freehand);
      expect(readState().exportedPath, isNull);
    });
  });

  group('Annotation model', () {
    test('FreehandAnnotation.addPoint appends point', () {
      const stroke = FreehandAnnotation(
        color: Color(0xFFFF0000),
        points: [Offset.zero, Offset(5, 5)],
      );
      final extended = stroke.addPoint(const Offset(10, 10));

      expect(extended.points.length, 3);
      expect(extended.points.last, const Offset(10, 10));
      expect(extended.color, stroke.color);
      expect(extended.strokeWidth, stroke.strokeWidth);
    });

    test('TextAnnotation holds position, text, and fontSize', () {
      const annotation = TextAnnotation(
        color: Color(0xFF0000FF),
        position: Offset(20, 30),
        text: 'Hello World',
        fontSize: 24.0,
      );

      expect(annotation.position, const Offset(20, 30));
      expect(annotation.text, 'Hello World');
      expect(annotation.fontSize, 24.0);
    });

    test('ArrowAnnotation holds start and end points', () {
      const annotation = ArrowAnnotation(
        color: Color(0xFF00FF00),
        start: Offset(10, 10),
        end: Offset(100, 100),
        strokeWidth: 5.0,
      );

      expect(annotation.start, const Offset(10, 10));
      expect(annotation.end, const Offset(100, 100));
      expect(annotation.strokeWidth, 5.0);
    });
  });

  group('ScreenshotState', () {
    test('copyWith preserves unmodified fields', () {
      const original = ScreenshotState(
        imagePath: '/tmp/test.png',
        selectedTool: AnnotationTool.text,
        selectedColor: Color(0xFF00FF00),
      );

      final modified = original.copyWith(selectedTool: AnnotationTool.arrow);

      expect(modified.imagePath, '/tmp/test.png');
      expect(modified.selectedTool, AnnotationTool.arrow);
      expect(modified.selectedColor, const Color(0xFF00FF00));
    });

    test('copyWith clearExportedPath nulls exportedPath', () {
      const original = ScreenshotState(exportedPath: '/tmp/exported.png');
      final modified = original.copyWith(clearExportedPath: true);

      expect(modified.exportedPath, isNull);
    });
  });
}
