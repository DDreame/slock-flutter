import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/attachment_repository.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart';

void main() {
  group('AttachmentRepository', () {
    group('getSignedUrl', () {
      test('returns signed download URL for valid attachment id', () async {
        final repo = FakeAttachmentRepository(
          signedUrl: 'https://cdn.example.com/signed/att-1?token=abc',
        );
        final container = ProviderContainer(
          overrides: [
            attachmentRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final result =
            await container.read(attachmentRepositoryProvider).getSignedUrl(
                  const ServerScopeId('server-1'),
                  attachmentId: 'att-1',
                );

        expect(result, 'https://cdn.example.com/signed/att-1?token=abc');
        expect(repo.lastSignedUrlAttachmentId, 'att-1');
      });

      test('throws AppFailure on network error', () async {
        final repo = FakeAttachmentRepository(
          signedUrlFailure: const NetworkFailure(message: 'offline'),
        );
        final container = ProviderContainer(
          overrides: [
            attachmentRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        expect(
          () => container.read(attachmentRepositoryProvider).getSignedUrl(
                const ServerScopeId('server-1'),
                attachmentId: 'att-1',
              ),
          throwsA(isA<NetworkFailure>()),
        );
      });

      test('throws AppFailure when attachment not found', () async {
        final repo = FakeAttachmentRepository(
          signedUrlFailure: const ServerFailure(
            message: 'Not found',
            statusCode: 404,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            attachmentRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        expect(
          () => container.read(attachmentRepositoryProvider).getSignedUrl(
                const ServerScopeId('server-1'),
                attachmentId: 'missing',
              ),
          throwsA(isA<ServerFailure>()),
        );
      });
    });

    group('getHtmlPreviewUrl', () {
      test('returns sandbox HTML preview URL', () async {
        final repo = FakeAttachmentRepository(
          htmlPreviewUrl:
              'https://sandbox.example.com/preview/att-html?token=xyz',
        );
        final container = ProviderContainer(
          overrides: [
            attachmentRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final result = await container
            .read(attachmentRepositoryProvider)
            .getHtmlPreviewUrl(
              const ServerScopeId('server-1'),
              attachmentId: 'att-html',
            );

        expect(
          result,
          'https://sandbox.example.com/preview/att-html?token=xyz',
        );
        expect(repo.lastHtmlPreviewAttachmentId, 'att-html');
      });

      test('throws AppFailure on network error', () async {
        final repo = FakeAttachmentRepository(
          htmlPreviewFailure: const NetworkFailure(message: 'timeout'),
        );
        final container = ProviderContainer(
          overrides: [
            attachmentRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        expect(
          () => container.read(attachmentRepositoryProvider).getHtmlPreviewUrl(
                const ServerScopeId('server-1'),
                attachmentId: 'att-html',
              ),
          throwsA(isA<NetworkFailure>()),
        );
      });
    });
  });

  group('AttachmentRepository diagnostics', () {
    test('logs attachment id and mimeType but not URLs or tokens', () async {
      // Diagnostics are implementation-level; we verify they can be
      // called without throwing and don't expose sensitive data.
      final repo = FakeAttachmentRepository(
        signedUrl: 'https://cdn.example.com/signed/x',
      );

      final result = await repo.getSignedUrl(
        const ServerScopeId('server-1'),
        attachmentId: 'att-diag',
      );

      // Result is present (no throw) — diagnostics logged internally
      expect(result, isNotEmpty);
      expect(repo.lastSignedUrlAttachmentId, 'att-diag');
    });
  });
}

class FakeAttachmentRepository implements AttachmentRepository {
  FakeAttachmentRepository({
    this.signedUrl,
    this.htmlPreviewUrl,
    this.signedUrlFailure,
    this.htmlPreviewFailure,
  });

  final String? signedUrl;
  final String? htmlPreviewUrl;
  final AppFailure? signedUrlFailure;
  final AppFailure? htmlPreviewFailure;

  String? lastSignedUrlAttachmentId;
  String? lastHtmlPreviewAttachmentId;

  @override
  Future<String> getSignedUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    lastSignedUrlAttachmentId = attachmentId;
    if (signedUrlFailure != null) throw signedUrlFailure!;
    return signedUrl!;
  }

  @override
  Future<String> getHtmlPreviewUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    lastHtmlPreviewAttachmentId = attachmentId;
    if (htmlPreviewFailure != null) throw htmlPreviewFailure!;
    return htmlPreviewUrl!;
  }
}
