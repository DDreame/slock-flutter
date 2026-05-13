import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/svg_preview_widget.dart';

void main() {
  testWidgets('SVG preview shows loading indicator initially (INV-ATTACH-1)',
      (tester) async {
    final attachment = MessageAttachment(
      name: 'icon.svg',
      type: 'image/svg+xml',
      url: 'https://example.com/icon.svg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SvgPreviewWidget(attachment: attachment),
        ),
      ),
    );

    // Initially shows loading state.
    expect(find.byKey(ValueKey('svg-loading-icon.svg')), findsOneWidget);
  });

  testWidgets('SVG preview shows fallback when no URL (INV-ATTACH-2)',
      (tester) async {
    final attachment = MessageAttachment(
      name: 'broken.svg',
      type: 'image/svg+xml',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SvgPreviewWidget(attachment: attachment),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should show fallback with error.
    expect(find.byKey(ValueKey('svg-fallback-broken.svg')), findsOneWidget);
    expect(find.text('No download URL'), findsOneWidget);
  });
}
