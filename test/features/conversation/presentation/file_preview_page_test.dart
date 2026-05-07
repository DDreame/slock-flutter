import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/attachment_repository.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart'
    show attachmentRepositoryProvider;
import 'package:slock_app/features/conversation/data/conversation_repository.dart'
    show MessageAttachment;
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/presentation/widgets/file_preview_page.dart';

void main() {
  // Suppress overflow errors in tests
  final overflowErrors = <FlutterErrorDetails>[];
  void Function(FlutterErrorDetails)? originalOnError;
  setUp(() {
    overflowErrors.clear();
    originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final exception = details.exception;
      if (exception is FlutterError &&
          exception.message.contains('overflowed')) {
        overflowErrors.add(details);
        return;
      }
      originalOnError?.call(details);
    };
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
  });

  group('FilePreviewPage routing', () {
    testWidgets('PDF attachment shows loading state initially', (
      tester,
    ) async {
      const attachment = MessageAttachment(
        name: 'report.pdf',
        type: 'application/pdf',
        id: 'att-1',
        sizeBytes: 1024000,
      );

      await tester.pumpWidget(
        _buildApp(
          attachment: attachment,
          fakeRepo: _FakeAttachmentRepository(),
        ),
      );

      // Should show loading state initially
      expect(
        find.byKey(const ValueKey('file-preview-loading')),
        findsOneWidget,
      );
      expect(find.text('Downloading PDF…'), findsOneWidget);
    });

    testWidgets('image attachment shows loading then image viewer', (
      tester,
    ) async {
      const attachment = MessageAttachment(
        name: 'photo.jpg',
        type: 'image/jpeg',
        id: 'att-2',
        url: 'https://example.com/photo.jpg',
      );

      await tester.pumpWidget(
        _buildApp(
          attachment: attachment,
          fakeRepo: _FakeAttachmentRepository(
            signedUrl: 'https://signed.example.com/photo.jpg',
          ),
        ),
      );

      // Initially loading
      expect(
        find.byKey(const ValueKey('file-preview-loading')),
        findsOneWidget,
      );

      await tester.pumpAndSettle();

      // After loading, should show image viewer
      expect(
        find.byKey(const ValueKey('image-viewer-interactive')),
        findsOneWidget,
      );
    });

    testWidgets('generic attachment shows loading then file info', (
      tester,
    ) async {
      const attachment = MessageAttachment(
        name: 'data.csv',
        type: 'text/csv',
        id: 'att-3',
        sizeBytes: 2048,
      );

      await tester.pumpWidget(
        _buildApp(
          attachment: attachment,
          fakeRepo: _FakeAttachmentRepository(
            signedUrl: 'https://signed.example.com/data.csv',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show generic file preview with file info
      expect(
        find.byKey(const ValueKey('generic-file-preview')),
        findsOneWidget,
      );
      expect(find.text('data.csv'), findsWidgets);
      expect(find.text('text/csv'), findsOneWidget);
      // Open with button
      expect(
        find.byKey(const ValueKey('generic-file-open')),
        findsOneWidget,
      );
    });
  });

  group('FilePreviewPage toolbar', () {
    testWidgets('toolbar shows filename and open-external button', (
      tester,
    ) async {
      const attachment = MessageAttachment(
        name: 'doc.txt',
        type: 'text/plain',
        id: 'att-4',
      );

      await tester.pumpWidget(
        _buildApp(
          attachment: attachment,
          fakeRepo: _FakeAttachmentRepository(
            signedUrl: 'https://signed.example.com/doc.txt',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toolbar present
      expect(
        find.byKey(const ValueKey('file-preview-toolbar')),
        findsOneWidget,
      );
      // Filename in title
      expect(find.text('doc.txt'), findsWidgets);
      // Open-external button always present
      expect(
        find.byKey(const ValueKey('file-preview-open-external')),
        findsOneWidget,
      );
    });

    testWidgets('share button appears after signed URL is loaded', (
      tester,
    ) async {
      const attachment = MessageAttachment(
        name: 'notes.txt',
        type: 'text/plain',
        id: 'att-5',
      );

      await tester.pumpWidget(
        _buildApp(
          attachment: attachment,
          fakeRepo: _FakeAttachmentRepository(
            signedUrl: 'https://signed.example.com/notes.txt',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Share button should appear after signed URL loads
      expect(
        find.byKey(const ValueKey('file-preview-share')),
        findsOneWidget,
      );
    });
  });

  group('FilePreviewPage error states', () {
    testWidgets('shows error state when signed URL fails', (tester) async {
      const attachment = MessageAttachment(
        name: 'report.pdf',
        type: 'application/pdf',
        id: 'att-6',
      );

      await tester.pumpWidget(
        _buildApp(
          attachment: attachment,
          fakeRepo: _FakeAttachmentRepository(shouldFail: true),
        ),
      );
      await tester.pumpAndSettle();

      // Should show error state
      expect(
        find.byKey(const ValueKey('file-preview-error')),
        findsOneWidget,
      );
      // Retry button
      expect(
        find.byKey(const ValueKey('file-preview-retry')),
        findsOneWidget,
      );
    });

    testWidgets('shows error when attachment has no id and no url', (
      tester,
    ) async {
      const attachment = MessageAttachment(
        name: 'orphan.bin',
        type: 'application/octet-stream',
      );

      await tester.pumpWidget(
        _buildApp(
          attachment: attachment,
          fakeRepo: _FakeAttachmentRepository(),
        ),
      );
      await tester.pumpAndSettle();

      // Should show error — no URL available
      expect(
        find.byKey(const ValueKey('file-preview-error')),
        findsOneWidget,
      );
      expect(find.text('No download URL available.'), findsOneWidget);
    });

    testWidgets('fallback to direct url when no id', (tester) async {
      const attachment = MessageAttachment(
        name: 'legacy.jpg',
        type: 'image/jpeg',
        url: 'https://direct.example.com/legacy.jpg',
      );

      await tester.pumpWidget(
        _buildApp(
          attachment: attachment,
          fakeRepo: _FakeAttachmentRepository(),
        ),
      );
      await tester.pumpAndSettle();

      // Should show image viewer using direct URL fallback
      expect(
        find.byKey(const ValueKey('image-viewer-interactive')),
        findsOneWidget,
      );
    });

    testWidgets('falls back to direct url when signed URL fails', (
      tester,
    ) async {
      const attachment = MessageAttachment(
        name: 'photo.png',
        type: 'image/png',
        id: 'att-fallback',
        url: 'https://direct.example.com/photo.png',
      );

      await tester.pumpWidget(
        _buildApp(
          attachment: attachment,
          fakeRepo: _FakeAttachmentRepository(shouldFail: true),
        ),
      );
      await tester.pumpAndSettle();

      // Should fall back to direct URL and show image viewer
      expect(
        find.byKey(const ValueKey('image-viewer-interactive')),
        findsOneWidget,
      );
    });

    testWidgets(
      'PDF falls back to direct url without flashing error when signed URL fails',
      (tester) async {
        const attachment = MessageAttachment(
          name: 'report.pdf',
          type: 'application/pdf',
          id: 'att-pdf-fallback',
          url: 'https://direct.example.com/report.pdf',
        );

        await tester.pumpWidget(
          _buildApp(
            attachment: attachment,
            fakeRepo: _FakeAttachmentRepository(shouldFail: true),
          ),
        );

        // After one pump the signed-URL failure fires and the fallback
        // branch starts _downloadPdf. _loading must still be true so
        // the spinner keeps showing — NOT the "PDF file not available."
        // error that appeared when _loading was set false too early.
        await tester.pump();

        expect(
          find.text('PDF file not available.'),
          findsNothing,
        );
        // Should still be in a loading or download-attempt state
        expect(
          find.byKey(const ValueKey('file-preview-loading')),
          findsOneWidget,
        );
      },
    );
  });

  group('FilePreviewPage page structure', () {
    testWidgets('page has correct key', (tester) async {
      const attachment = MessageAttachment(
        name: 'test.txt',
        type: 'text/plain',
        url: 'https://example.com/test.txt',
      );

      await tester.pumpWidget(
        _buildApp(
          attachment: attachment,
          fakeRepo: _FakeAttachmentRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('file-preview-page')),
        findsOneWidget,
      );
    });

    testWidgets('generic file shows formatted size', (tester) async {
      const attachment = MessageAttachment(
        name: 'data.zip',
        type: 'application/zip',
        url: 'https://example.com/data.zip',
        sizeBytes: 5242880, // 5 MB
      );

      await tester.pumpWidget(
        _buildApp(
          attachment: attachment,
          fakeRepo: _FakeAttachmentRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('generic-file-preview')),
        findsOneWidget,
      );
      expect(find.text('data.zip'), findsWidgets);
      // Size should be formatted
      expect(find.text(attachment.formattedSize!), findsOneWidget);
    });
  });
}

Widget _buildApp({
  required MessageAttachment attachment,
  required _FakeAttachmentRepository fakeRepo,
}) {
  return ProviderScope(
    overrides: [
      attachmentRepositoryProvider.overrideWithValue(fakeRepo),
      currentOpenConversationTargetProvider.overrideWith(
        (ref) => null,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: FilePreviewPage(attachment: attachment),
    ),
  );
}

class _FakeAttachmentRepository implements AttachmentRepository {
  _FakeAttachmentRepository({
    this.signedUrl,
    this.shouldFail = false,
  });

  final String? signedUrl;
  final bool shouldFail;

  @override
  Future<String> getSignedUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    if (shouldFail) {
      throw const NetworkFailure(message: 'Network error');
    }
    if (signedUrl != null) return signedUrl!;
    return 'https://signed.example.com/$attachmentId';
  }

  @override
  Future<String> getHtmlPreviewUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    return 'https://preview.example.com/$attachmentId';
  }
}
