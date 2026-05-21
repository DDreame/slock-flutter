// =============================================================================
// #677 — ==/hashCode for ScreenshotState + TranslationSettingsState
//
// Invariant: INV-REBUILD-SUPPRESS-677
//   copyWith(same values) produces == state, suppressing unnecessary rebuilds.
// =============================================================================

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';
import 'package:slock_app/features/screenshot/data/screenshot_state.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';

void main() {
  group('ScreenshotState ==', () {
    test('default instances are equal', () {
      const a = ScreenshotState();
      const b = ScreenshotState();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith(same values) produces equal state', () {
      const state = ScreenshotState(
        imagePath: '/tmp/shot.png',
        annotations: [
          FreehandAnnotation(
            color: Color(0xFFFF0000),
            points: [Offset(0, 0), Offset(10, 10)],
          ),
        ],
        undoneAnnotations: [
          ArrowAnnotation(
            color: Color(0xFF00FF00),
            start: Offset(5, 5),
            end: Offset(20, 20),
          ),
        ],
        selectedTool: AnnotationTool.arrow,
        selectedColor: Color(0xFF0000FF),
        isExporting: true,
        exportedPath: '/tmp/exported.png',
      );

      final copy = state.copyWith();
      expect(copy, equals(state));
      expect(copy.hashCode, equals(state.hashCode));
    });

    test('different imagePath produces unequal state', () {
      const a = ScreenshotState(imagePath: '/a.png');
      const b = ScreenshotState(imagePath: '/b.png');
      expect(a, isNot(equals(b)));
    });

    test('different annotations produces unequal state', () {
      const a = ScreenshotState(annotations: [
        TextAnnotation(
          color: Color(0xFFFF0000),
          position: Offset(0, 0),
          text: 'hello',
        ),
      ]);
      const b = ScreenshotState(annotations: []);
      expect(a, isNot(equals(b)));
    });

    test('different selectedTool produces unequal state', () {
      const a = ScreenshotState(selectedTool: AnnotationTool.freehand);
      const b = ScreenshotState(selectedTool: AnnotationTool.text);
      expect(a, isNot(equals(b)));
    });

    test('different selectedColor produces unequal state', () {
      const a = ScreenshotState(selectedColor: Color(0xFFFF0000));
      const b = ScreenshotState(selectedColor: Color(0xFF00FF00));
      expect(a, isNot(equals(b)));
    });

    test('different isExporting produces unequal state', () {
      const a = ScreenshotState(isExporting: false);
      const b = ScreenshotState(isExporting: true);
      expect(a, isNot(equals(b)));
    });

    test('different exportedPath produces unequal state', () {
      const a = ScreenshotState(exportedPath: '/a.png');
      const b = ScreenshotState(exportedPath: '/b.png');
      expect(a, isNot(equals(b)));
    });
  });

  group('TranslationSettingsState ==', () {
    test('default instances are equal', () {
      const a = TranslationSettingsState();
      const b = TranslationSettingsState();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith(same values) produces equal state', () {
      const state = TranslationSettingsState(
        status: TranslationSettingsStatus.success,
        settings: TranslationSettings(
          preferredLanguage: 'zh',
          mode: TranslationMode.auto,
        ),
      );

      final copy = state.copyWith();
      expect(copy, equals(state));
      expect(copy.hashCode, equals(state.hashCode));
    });

    test('different status produces unequal state', () {
      const a = TranslationSettingsState(
        status: TranslationSettingsStatus.initial,
      );
      const b = TranslationSettingsState(
        status: TranslationSettingsStatus.loading,
      );
      expect(a, isNot(equals(b)));
    });

    test('different settings produces unequal state', () {
      const a = TranslationSettingsState(
        settings: TranslationSettings(preferredLanguage: 'en'),
      );
      const b = TranslationSettingsState(
        settings: TranslationSettings(preferredLanguage: 'zh'),
      );
      expect(a, isNot(equals(b)));
    });

    test('different failure produces unequal state', () {
      const failure = UnknownFailure(message: 'test error');
      const a = TranslationSettingsState(failure: failure);
      const b = TranslationSettingsState();
      expect(a, isNot(equals(b)));
    });

    test('copyWith clearFailure produces different state when failure set', () {
      const state = TranslationSettingsState(
        status: TranslationSettingsStatus.failure,
        failure: UnknownFailure(message: 'err'),
      );
      final cleared = state.copyWith(clearFailure: true);
      expect(cleared, isNot(equals(state)));
    });
  });
}
