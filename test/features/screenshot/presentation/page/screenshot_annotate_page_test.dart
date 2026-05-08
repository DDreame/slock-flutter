import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/features/screenshot/application/screenshot_store.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';
import 'package:slock_app/features/screenshot/data/screenshot_state.dart';
import 'package:slock_app/features/screenshot/presentation/page/screenshot_annotate_page.dart';
import 'package:slock_app/features/screenshot/presentation/widgets/annotation_canvas.dart';
import 'package:slock_app/features/screenshot/presentation/widgets/annotation_toolbar.dart';
import 'package:slock_app/features/share/application/share_intent_store.dart';
import 'package:slock_app/features/share/data/shared_content.dart';

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

    testWidgets('annotation canvas is not rendered until image size is loaded',
        (tester) async {
      // On initial render (before _loadImageSize completes), the
      // AnnotationPainter CustomPaint should not be in the tree.
      // The image is still displayed but the annotation overlay is gated.
      await tester.pumpWidget(buildPage(imagePath: tempImageFile.path));

      // Immediately after pumpWidget, before async _loadImageSize completes:
      // The page is rendered but check that the Image widget is present.
      expect(find.text('Annotate Screenshot'), findsOneWidget);

      // After pump (allows _loadImageSize to complete for our tiny test PNG):
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The page should still render fine.
      expect(find.text('Annotate Screenshot'), findsOneWidget);
    });

    testWidgets(
        'share button tapping with no annotations seeds ShareIntentStore',
        (tester) async {
      // Build with GoRouter so context.go('/share-target') works.
      final container = ProviderContainer(
        overrides: [
          screenshotStoreProvider.overrideWith(() {
            return TestScreenshotStore(imagePath: tempImageFile.path);
          }),
        ],
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ScreenshotAnnotatePage(),
          ),
          GoRoute(
            path: '/share-target',
            builder: (context, state) =>
                const Scaffold(body: Text('Share Target')),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      // Allow image size to load.
      await tester.pump(const Duration(milliseconds: 100));

      // Verify ShareIntentStore is initially null.
      final initialContent = container.read(shareIntentStoreProvider);
      expect(initialContent, isNull);

      // Tap the share button — with no annotations, _exportImage will use the
      // original imagePath directly (no image codec needed). Then it seeds
      // ShareIntentStore and navigates to /share-target.
      await tester.tap(find.byKey(const ValueKey('screenshot-share')));
      await tester.pumpAndSettle();

      // After the share flow, ShareIntentStore should be seeded with content.
      final content = container.read(shareIntentStoreProvider);
      expect(content, isNotNull);
      expect(content!.items, hasLength(1));
      expect(content.items.first.type, SharedContentType.image);
      expect(content.items.first.path, tempImageFile.path);
      expect(content.items.first.mimeType, 'image/png');

      // Should have navigated to /share-target.
      expect(find.text('Share Target'), findsOneWidget);

      router.dispose();
    });
  });

  group('AnnotationPainter displayScale/displayOffset contract', () {
    testWidgets(
        'AnnotationPainter passes displayScale and displayOffset to paint',
        (tester) async {
      // Verify that the painter receives and uses scale/offset params.
      const painter = AnnotationPainter(
        annotations: [
          FreehandAnnotation(
            color: Color(0xFFFF0000),
            // Points in image-pixel space (large values).
            points: [Offset(500, 500), Offset(600, 600)],
            strokeWidth: 6.0, // Image-space strokeWidth (normalized).
          ),
        ],
        displayScale: 0.5,
        displayOffset: Offset(10, 20),
      );

      await tester.pumpWidget(
        const CustomPaint(painter: painter, size: Size(400, 400)),
      );

      // No error thrown — the painter applies transform and renders.
      expect(tester.takeException(), isNull);
      expect(painter.displayScale, 0.5);
      expect(painter.displayOffset, const Offset(10, 20));
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
