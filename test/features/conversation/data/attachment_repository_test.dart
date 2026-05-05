import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/attachment_repository.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

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

  group('AttachmentRepository diagnostics regression', () {
    test('real provider records info diagnostic on successful getSignedUrl',
        () async {
      final diagnostics = DiagnosticsCollector();
      final dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter(
        responseData: '{"url": "https://signed.url/x"}',
      );
      final dioClient = AppDioClient(dio);

      final container = ProviderContainer(
        overrides: [
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
          appDioClientProvider.overrideWithValue(dioClient),
        ],
      );
      addTearDown(container.dispose);

      final result =
          await container.read(attachmentRepositoryProvider).getSignedUrl(
                const ServerScopeId('server-1'),
                attachmentId: 'att-diag',
              );

      expect(result, 'https://signed.url/x');
      final entries = diagnostics.entries
          .where((e) => e.tag == 'attachment-preview')
          .toList();
      expect(entries, hasLength(1));
      expect(entries.first.level, DiagnosticsLevel.info);
      expect(entries.first.message, contains('source=signedUrl'));
      expect(entries.first.message, contains('attachmentId=att-diag'));
      // Must not leak the signed URL in diagnostics
      expect(entries.first.message, isNot(contains('https://')));
    });

    test('real provider records error diagnostic on getSignedUrl failure',
        () async {
      final diagnostics = DiagnosticsCollector();
      final dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter(
        statusCode: 500,
        responseData: '{"error": "internal"}',
      );
      final dioClient = AppDioClient(dio);

      final container = ProviderContainer(
        overrides: [
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
          appDioClientProvider.overrideWithValue(dioClient),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        () => container.read(attachmentRepositoryProvider).getSignedUrl(
              const ServerScopeId('server-1'),
              attachmentId: 'att-err',
            ),
        throwsA(isA<AppFailure>()),
      );

      final errors = diagnostics.entries
          .where((e) =>
              e.tag == 'attachment-preview' &&
              e.level == DiagnosticsLevel.error)
          .toList();
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('attachmentId=att-err'));
      expect(errors.first.message, contains('failureType='));
      expect(errors.first.message, isNot(contains('https://')));
    });

    test(
        'real provider records info diagnostic on successful getHtmlPreviewUrl',
        () async {
      final diagnostics = DiagnosticsCollector();
      final dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter(
        responseData: '{"url": "https://sandbox.url/preview"}',
      );
      final dioClient = AppDioClient(dio);

      final container = ProviderContainer(
        overrides: [
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
          appDioClientProvider.overrideWithValue(dioClient),
        ],
      );
      addTearDown(container.dispose);

      final result =
          await container.read(attachmentRepositoryProvider).getHtmlPreviewUrl(
                const ServerScopeId('server-1'),
                attachmentId: 'att-html-diag',
              );

      expect(result, 'https://sandbox.url/preview');
      final entries = diagnostics.entries
          .where((e) => e.tag == 'attachment-preview')
          .toList();
      expect(entries, hasLength(1));
      expect(entries.first.level, DiagnosticsLevel.info);
      expect(entries.first.message, contains('source=htmlPreview'));
      expect(entries.first.message, contains('attachmentId=att-html-diag'));
      expect(entries.first.message, isNot(contains('https://')));
    });

    test('real provider records error on getHtmlPreviewUrl failure', () async {
      final diagnostics = DiagnosticsCollector();
      final dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter(
        statusCode: 404,
        responseData: '{"error": "not found"}',
      );
      final dioClient = AppDioClient(dio);

      final container = ProviderContainer(
        overrides: [
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
          appDioClientProvider.overrideWithValue(dioClient),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        () => container.read(attachmentRepositoryProvider).getHtmlPreviewUrl(
              const ServerScopeId('server-1'),
              attachmentId: 'att-missing',
            ),
        throwsA(isA<AppFailure>()),
      );

      final errors = diagnostics.entries
          .where((e) =>
              e.tag == 'attachment-preview' &&
              e.level == DiagnosticsLevel.error)
          .toList();
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('failureType='));
      expect(errors.first.message, contains('attachmentId=att-missing'));
      expect(errors.first.message, isNot(contains('https://')));
    });
  });

  group('Round-trip persistence', () {
    test('MessageAttachment with thumbnailUrl survives encode/decode', () {
      const original = MessageAttachment(
        name: 'photo.png',
        type: 'image/png',
        url: 'https://direct.example.com/photo.png',
        id: 'att-rt',
        sizeBytes: 12345,
        thumbnailUrl: 'https://thumb.example.com/photo.png',
      );

      // Simulate encode (same as conversation_repository_provider.dart)
      final encoded = <String, dynamic>{
        'name': original.name,
        'type': original.type,
        if (original.url != null) 'url': original.url,
        if (original.id != null) 'id': original.id,
        if (original.sizeBytes != null) 'sizeBytes': original.sizeBytes,
        if (original.thumbnailUrl != null)
          'thumbnailUrl': original.thumbnailUrl,
      };

      // Simulate decode (same logic as _decodeAttachments)
      final thumbnailUrl = encoded['thumbnailUrl'] as String?;
      final decoded = MessageAttachment(
        name: encoded['name'] as String,
        type: encoded['type'] as String,
        url: (encoded['url'] as String?) ?? thumbnailUrl,
        id: encoded['id'] as String?,
        sizeBytes: encoded['sizeBytes'] as int?,
        thumbnailUrl: thumbnailUrl,
      );

      expect(decoded.name, original.name);
      expect(decoded.type, original.type);
      expect(decoded.url, original.url);
      expect(decoded.id, original.id);
      expect(decoded.sizeBytes, original.sizeBytes);
      expect(decoded.thumbnailUrl, original.thumbnailUrl);
      expect(decoded, equals(original));
    });

    test('MessageAttachment without thumbnailUrl round-trips cleanly', () {
      const original = MessageAttachment(
        name: 'doc.pdf',
        type: 'application/pdf',
        url: 'https://example.com/doc.pdf',
        id: 'att-pdf',
        sizeBytes: 999,
      );

      final encoded = <String, dynamic>{
        'name': original.name,
        'type': original.type,
        if (original.url != null) 'url': original.url,
        if (original.id != null) 'id': original.id,
        if (original.sizeBytes != null) 'sizeBytes': original.sizeBytes,
        if (original.thumbnailUrl != null)
          'thumbnailUrl': original.thumbnailUrl,
      };

      final thumbnailUrl = encoded['thumbnailUrl'] as String?;
      final decoded = MessageAttachment(
        name: encoded['name'] as String,
        type: encoded['type'] as String,
        url: (encoded['url'] as String?) ?? thumbnailUrl,
        id: encoded['id'] as String?,
        sizeBytes: encoded['sizeBytes'] as int?,
        thumbnailUrl: thumbnailUrl,
      );

      expect(decoded, equals(original));
      expect(decoded.thumbnailUrl, isNull);
    });

    test('New-style payload with only thumbnailUrl maps it as url fallback',
        () {
      // Simulate a new-style payload that has no old `url` field
      final encoded = <String, dynamic>{
        'name': 'new.png',
        'type': 'image/png',
        'id': 'att-new',
        'thumbnailUrl': 'https://thumb.example.com/new.png',
      };

      final thumbnailUrl = encoded['thumbnailUrl'] as String?;
      final decoded = MessageAttachment(
        name: encoded['name'] as String,
        type: encoded['type'] as String,
        url: (encoded['url'] as String?) ?? thumbnailUrl,
        id: encoded['id'] as String?,
        sizeBytes: encoded['sizeBytes'] as int?,
        thumbnailUrl: thumbnailUrl,
      );

      expect(decoded.url, 'https://thumb.example.com/new.png',
          reason: 'When no url field, thumbnailUrl should be used as url');
      expect(decoded.thumbnailUrl, 'https://thumb.example.com/new.png');
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

/// Fake HTTP adapter that returns configured responses for Dio.
class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({
    required this.responseData,
    this.statusCode = 200,
  });

  final String responseData;
  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: statusCode,
          data: responseData,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(
      responseData,
      statusCode,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
