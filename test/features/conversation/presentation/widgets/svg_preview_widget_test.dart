import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/svg_preview_widget.dart';

void main() {
  testWidgets(
      'SVG preview renders inline SVG from fetched content (INV-ATTACH-1)',
      (tester) async {
    final attachment = MessageAttachment(
      name: 'icon.svg',
      type: 'image/svg+xml',
      url: 'https://example.com/icon.svg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SvgPreviewWidget(
            attachment: attachment,
            contentFetcher: (url) async =>
                '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">'
                '<circle cx="50" cy="50" r="40" fill="red"/>'
                '</svg>',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should show the SVG preview.
    expect(find.byKey(ValueKey('svg-preview-icon.svg')), findsOneWidget);
  });

  testWidgets('SVG preview shows fallback when fetch fails (INV-ATTACH-2)',
      (tester) async {
    final fallback = Container(key: const ValueKey('test-fallback'));
    final attachment = MessageAttachment(
      name: 'broken.svg',
      type: 'image/svg+xml',
      url: 'https://example.com/broken.svg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SvgPreviewWidget(
            attachment: attachment,
            fallback: fallback,
            contentFetcher: (url) async => throw Exception('network error'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('test-fallback')), findsOneWidget);
  });

  testWidgets('SVG preview shows fallback when no URL (INV-ATTACH-2)',
      (tester) async {
    final fallback = Container(key: const ValueKey('test-fallback-no-url'));
    final attachment = MessageAttachment(
      name: 'no-url.svg',
      type: 'image/svg+xml',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SvgPreviewWidget(
            attachment: attachment,
            fallback: fallback,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('test-fallback-no-url')), findsOneWidget);
  });
}
