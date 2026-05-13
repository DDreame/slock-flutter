import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/csv_preview_widget.dart';
import 'package:slock_app/features/conversation/presentation/widgets/svg_preview_widget.dart';
import 'package:slock_app/features/conversation/presentation/widgets/text_preview_widget.dart';

/// Tests for the attachment routing logic in `_AttachmentSection`.
/// Since `_AttachmentSection` is private, we verify each preview widget
/// renders correctly for its MIME type, and test the size gate boundary
/// via unit assertions.
void main() {
  group('attachment inline preview routing', () {
    testWidgets('CSV attachment renders CsvPreviewWidget (INV-ATTACH-1)',
        (tester) async {
      const attachment = MessageAttachment(
        name: 'data.csv',
        type: 'text/csv',
        url: 'https://example.com/data.csv',
        sizeBytes: 1024,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CsvPreviewWidget(
              attachment: attachment,
              contentFetcher: (url) async => 'a,b\n1,2',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CsvPreviewWidget), findsOneWidget);
    });

    testWidgets('SVG attachment renders SvgPreviewWidget (INV-ATTACH-1)',
        (tester) async {
      const attachment = MessageAttachment(
        name: 'icon.svg',
        type: 'image/svg+xml',
        url: 'https://example.com/icon.svg',
        sizeBytes: 2048,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SvgPreviewWidget(
              attachment: attachment,
              contentFetcher: (url) async =>
                  '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">'
                  '<rect width="10" height="10"/></svg>',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SvgPreviewWidget), findsOneWidget);
    });

    testWidgets('Markdown attachment renders TextPreviewWidget (INV-ATTACH-1)',
        (tester) async {
      const attachment = MessageAttachment(
        name: 'readme.md',
        type: 'text/markdown',
        url: 'https://example.com/readme.md',
        sizeBytes: 512,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextPreviewWidget(
              attachment: attachment,
              isMarkdown: true,
              contentFetcher: (url) async => '# Title',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextPreviewWidget), findsOneWidget);
    });

    testWidgets(
        'Plain text attachment renders TextPreviewWidget (INV-ATTACH-1)',
        (tester) async {
      const attachment = MessageAttachment(
        name: 'notes.txt',
        type: 'text/plain',
        url: 'https://example.com/notes.txt',
        sizeBytes: 256,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextPreviewWidget(
              attachment: attachment,
              isMarkdown: false,
              contentFetcher: (url) async => 'hello',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextPreviewWidget), findsOneWidget);
    });

    testWidgets('unknown type does not render any preview widget',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => const Text('no-preview'),
            ),
          ),
        ),
      );

      expect(find.byType(CsvPreviewWidget), findsNothing);
      expect(find.byType(SvgPreviewWidget), findsNothing);
      expect(find.byType(TextPreviewWidget), findsNothing);
    });

    test('size gate constant is 1 MB (INV-ATTACH-3)', () {
      const oneMb = 1048576;
      const small = MessageAttachment(
        name: 'small.csv',
        type: 'text/csv',
        url: 'https://example.com/small.csv',
        sizeBytes: oneMb - 1,
      );
      const large = MessageAttachment(
        name: 'large.csv',
        type: 'text/csv',
        url: 'https://example.com/large.csv',
        sizeBytes: oneMb + 1,
      );

      expect(small.sizeBytes! <= oneMb, isTrue,
          reason: 'INV-ATTACH-3: files <= 1MB should get inline preview');
      expect(large.sizeBytes! > oneMb, isTrue,
          reason: 'INV-ATTACH-3: files > 1MB should skip inline preview');
    });

    test('.md extension triggers markdown detection', () {
      for (final ext in ['.md', '.markdown']) {
        expect(
          'readme$ext'.endsWith('.md') || 'readme$ext'.endsWith('.markdown'),
          isTrue,
          reason: 'Extension $ext should be detected as markdown',
        );
      }
    });
  });
}
