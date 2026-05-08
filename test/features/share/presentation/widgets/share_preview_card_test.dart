import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/features/share/presentation/widgets/share_preview_card.dart';

void main() {
  Widget buildApp(SharedContent content) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SharePreviewCard(content: content)),
    );
  }

  group('SharePreviewCard', () {
    testWidgets('shows text content', (tester) async {
      const content = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'Hello world'),
      ]);
      await tester.pumpWidget(buildApp(content));

      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('shows URL content', (tester) async {
      const content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.url,
          path: 'https://example.com',
        ),
      ]);
      await tester.pumpWidget(buildApp(content));

      expect(find.text('https://example.com'), findsOneWidget);
    });

    testWidgets('shows combined text for multiple text items', (tester) async {
      const content = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'Line 1'),
        SharedContentItem(
          type: SharedContentType.url,
          path: 'https://example.com',
        ),
      ]);
      await tester.pumpWidget(buildApp(content));

      expect(find.text('Line 1\nhttps://example.com'), findsOneWidget);
    });

    testWidgets('shows attachment count for images', (tester) async {
      const content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.image,
          path: '/tmp/photo.jpg',
          mimeType: 'image/jpeg',
        ),
      ]);
      await tester.pumpWidget(buildApp(content));

      expect(find.text('1 attachment'), findsOneWidget);
    });

    testWidgets('shows plural attachment count', (tester) async {
      const content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.image,
          path: '/tmp/photo1.jpg',
          mimeType: 'image/jpeg',
        ),
        SharedContentItem(
          type: SharedContentType.video,
          path: '/tmp/video.mp4',
          mimeType: 'video/mp4',
        ),
        SharedContentItem(
          type: SharedContentType.file,
          path: '/tmp/doc.pdf',
          mimeType: 'application/pdf',
        ),
      ]);
      await tester.pumpWidget(buildApp(content));

      expect(find.text('3 attachments'), findsOneWidget);
    });

    testWidgets('shows both text and attachment info', (tester) async {
      const content = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'Check this out'),
        SharedContentItem(
          type: SharedContentType.image,
          path: '/tmp/photo.jpg',
          mimeType: 'image/jpeg',
        ),
      ]);
      await tester.pumpWidget(buildApp(content));

      expect(find.text('Check this out'), findsOneWidget);
      expect(find.text('1 attachment'), findsOneWidget);
    });

    testWidgets('shows file icon for attachments', (tester) async {
      const content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.file,
          path: '/tmp/doc.pdf',
          mimeType: 'application/pdf',
        ),
      ]);
      await tester.pumpWidget(buildApp(content));

      expect(find.byIcon(Icons.attach_file), findsOneWidget);
    });

    testWidgets('renders nothing visible for empty content', (tester) async {
      const content = SharedContent(items: []);
      await tester.pumpWidget(buildApp(content));

      // The widget renders but shows nothing meaningful.
      expect(find.byType(SharePreviewCard), findsOneWidget);
    });
  });
}
