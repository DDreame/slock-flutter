import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/screenshot/application/screenshot_store.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';
import 'package:slock_app/features/screenshot/data/screenshot_state.dart';
import 'package:slock_app/features/screenshot/presentation/page/screenshot_annotate_page.dart';
import 'package:slock_app/features/screenshot/presentation/widgets/annotation_toolbar.dart';

void main() {
  group('ScreenshotAnnotatePage', () {
    late File tempImageFile;

    setUpAll(() {
      // Create a minimal valid 1x1 red PNG for testing.
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, // IHDR length
        0x49, 0x48, 0x44, 0x52, // IHDR
        0x00, 0x00, 0x00, 0x01, // width = 1
        0x00, 0x00, 0x00, 0x01, // height = 1
        0x08, 0x02, // 8-bit RGB
        0x00, 0x00, 0x00, // compression, filter, interlace
        0x90, 0x77, 0x53, 0xDE, // IHDR CRC
        0x00, 0x00, 0x00, 0x0C, // IDAT length
        0x49, 0x44, 0x41, 0x54, // IDAT
        0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
        0x00, 0x02, 0x00, 0x01, // compressed data
        0xE2, 0x21, 0xBC, 0x33, // IDAT CRC
        0x00, 0x00, 0x00, 0x00, // IEND length
        0x49, 0x45, 0x4E, 0x44, // IEND
        0xAE, 0x42, 0x60, 0x82, // IEND CRC
      ]);
      tempImageFile = File(
        '${Directory.systemTemp.path}/test_screenshot_page.png',
      )..writeAsBytesSync(pngBytes);
    });

    tearDownAll(() {
      if (tempImageFile.existsSync()) {
        tempImageFile.deleteSync();
      }
    });

    Widget buildPage({String? imagePath}) {
      return ProviderScope(
        overrides: [
          screenshotStoreProvider.overrideWith(() {
            return TestScreenshotStore(imagePath: imagePath);
          }),
        ],
        child: const MaterialApp(
          home: ScreenshotAnnotatePage(),
        ),
      );
    }

    testWidgets('shows "No screenshot captured" when imagePath is null',
        (tester) async {
      await tester.pumpWidget(buildPage());

      expect(find.text('No screenshot captured'), findsOneWidget);
    });

    testWidgets('renders annotate page when imagePath is set', (tester) async {
      await tester.pumpWidget(buildPage(imagePath: tempImageFile.path));
      await tester.pump();

      expect(find.text('Annotate Screenshot'), findsOneWidget);
      expect(find.byKey(const ValueKey('screenshot-discard')), findsOneWidget);
      expect(find.byKey(const ValueKey('screenshot-share')), findsOneWidget);
    });

    testWidgets('renders save button when imagePath is set', (tester) async {
      await tester.pumpWidget(buildPage(imagePath: tempImageFile.path));
      await tester.pump();

      expect(find.byKey(const ValueKey('screenshot-save')), findsOneWidget);
      expect(find.byIcon(Icons.save_alt), findsOneWidget);
    });

    testWidgets('discard button pops the page and resets store',
        (tester) async {
      // Wrap in a Navigator so pop() works.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            screenshotStoreProvider.overrideWith(() {
              return TestScreenshotStore(imagePath: tempImageFile.path);
            }),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ScreenshotAnnotatePage(),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Navigate to the annotate page.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Annotate Screenshot'), findsOneWidget);

      // Tap discard.
      await tester.tap(find.byKey(const ValueKey('screenshot-discard')));
      await tester.pumpAndSettle();

      // Should have popped back.
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Annotate Screenshot'), findsNothing);
    });

    testWidgets('toolbar is rendered with tool buttons', (tester) async {
      await tester.pumpWidget(buildPage(imagePath: tempImageFile.path));
      await tester.pump();

      // Verify toolbar tool icons are present.
      expect(find.byIcon(Icons.brush), findsOneWidget);
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.byIcon(Icons.undo), findsOneWidget);
      expect(find.byIcon(Icons.redo), findsOneWidget);
    });

    testWidgets('toolbar is an AnnotationToolbar widget', (tester) async {
      await tester.pumpWidget(buildPage(imagePath: tempImageFile.path));
      await tester.pump();

      expect(find.byType(AnnotationToolbar), findsOneWidget);
    });

    testWidgets('save and share buttons are disabled while exporting',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            screenshotStoreProvider.overrideWith(() {
              return TestScreenshotStore(
                imagePath: tempImageFile.path,
                initialExporting: true,
              );
            }),
          ],
          child: const MaterialApp(
            home: ScreenshotAnnotatePage(),
          ),
        ),
      );
      await tester.pump();

      // Both save and share should be rendered but their onPressed is null.
      final saveButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('screenshot-save')),
      );
      expect(saveButton.onPressed, isNull);

      final shareButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('screenshot-share')),
      );
      expect(shareButton.onPressed, isNull);
    });

    testWidgets('shows loading overlay when isExporting', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            screenshotStoreProvider.overrideWith(() {
              return TestScreenshotStore(
                imagePath: tempImageFile.path,
                initialExporting: true,
              );
            }),
          ],
          child: const MaterialApp(
            home: ScreenshotAnnotatePage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('page renders with annotations in state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            screenshotStoreProvider.overrideWith(() {
              return TestScreenshotStore(
                imagePath: tempImageFile.path,
                initialAnnotations: [
                  const ArrowAnnotation(
                    color: Color(0xFFFF0000),
                    start: Offset(10, 10),
                    end: Offset(100, 100),
                  ),
                ],
              );
            }),
          ],
          child: const MaterialApp(
            home: ScreenshotAnnotatePage(),
          ),
        ),
      );
      await tester.pump();

      // Page renders without errors.
      expect(find.text('Annotate Screenshot'), findsOneWidget);
      // Undo should be enabled since there's an annotation.
      final undoButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.undo),
      );
      expect(undoButton.onPressed, isNotNull);
    });
  });
}

/// Test store that can be pre-seeded with state.
class TestScreenshotStore extends ScreenshotStore {
  TestScreenshotStore({
    this.imagePath,
    this.initialExporting = false,
    this.initialAnnotations = const [],
  });

  final String? imagePath;
  final bool initialExporting;
  final List<Annotation> initialAnnotations;

  @override
  ScreenshotState build() {
    return ScreenshotState(
      imagePath: imagePath,
      isExporting: initialExporting,
      annotations: initialAnnotations,
    );
  }
}
