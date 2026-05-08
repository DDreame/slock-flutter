import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/link_preview/data/link_preview_service.dart';

void main() {
  group('URL extraction', () {
    test('extractFirstUrl finds https URL', () {
      expect(
        extractFirstUrl('Check out https://example.com/page for details'),
        'https://example.com/page',
      );
    });

    test('extractFirstUrl finds http URL', () {
      expect(
        extractFirstUrl('Visit http://example.com'),
        'http://example.com',
      );
    });

    test('extractFirstUrl returns null when no URL present', () {
      expect(extractFirstUrl('No links here'), isNull);
    });

    test('extractFirstUrl strips trailing period', () {
      expect(
        extractFirstUrl('Go to https://example.com.'),
        'https://example.com',
      );
    });

    test('extractFirstUrl strips trailing comma', () {
      expect(
        extractFirstUrl('Visit https://example.com, then come back'),
        'https://example.com',
      );
    });

    test('extractFirstUrl strips trailing closing paren', () {
      expect(
        extractFirstUrl('(see https://example.com)'),
        'https://example.com',
      );
    });

    test('extractFirstUrl strips trailing exclamation', () {
      expect(
        extractFirstUrl('Look at https://example.com/cool!'),
        'https://example.com/cool',
      );
    });

    test('extractFirstUrl strips trailing question mark', () {
      expect(
        extractFirstUrl('Is this https://example.com?'),
        'https://example.com',
      );
    });

    test('extractFirstUrl preserves query parameters', () {
      expect(
        extractFirstUrl('https://example.com/page?foo=bar&baz=1'),
        'https://example.com/page?foo=bar&baz=1',
      );
    });

    test('extractFirstUrl preserves URL path', () {
      expect(
        extractFirstUrl('https://example.com/path/to/resource'),
        'https://example.com/path/to/resource',
      );
    });

    test('extractFirstUrl preserves fragment', () {
      expect(
        extractFirstUrl('https://example.com/page#section'),
        'https://example.com/page#section',
      );
    });

    test('extractFirstUrl returns first URL when multiple present', () {
      expect(
        extractFirstUrl('Check https://first.com and https://second.com too'),
        'https://first.com',
      );
    });

    test('extractAllUrls finds all URLs', () {
      expect(
        extractAllUrls('Visit https://a.com and https://b.com/page.'),
        ['https://a.com', 'https://b.com/page'],
      );
    });

    test('extractAllUrls returns empty list when no URLs', () {
      expect(extractAllUrls('No links here'), isEmpty);
    });

    test('extractFirstUrl strips multiple trailing punctuation chars', () {
      expect(
        extractFirstUrl('See https://example.com...'),
        'https://example.com',
      );
    });

    test('extractFirstUrl handles URL with port', () {
      expect(
        extractFirstUrl('http://localhost:3000/page'),
        'http://localhost:3000/page',
      );
    });
  });

  group('LinkPreviewService', () {
    test('fetchMetadata returns null on network error', () async {
      // Use a Dio with a bad base URL to simulate failure.
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(milliseconds: 100),
        receiveTimeout: const Duration(milliseconds: 100),
      ));
      final service = LinkPreviewService(dio: dio);
      final result = await service.fetchMetadata('https://nonexistent.invalid');
      expect(result, isNull);
    });

    test('parseHtml extracts OG tags', () {
      // Test the parsing logic by constructing a service and using
      // a mock adapter or testing the parser directly.
      // Since _parseHtml is private, we test through a custom Dio adapter.
      final service = LinkPreviewService(
        dio: _createMockDio(
          '<html><head>'
          '<meta property="og:title" content="Test Title">'
          '<meta property="og:description" content="Test Description">'
          '<meta property="og:image" content="https://example.com/img.jpg">'
          '</head><body></body></html>',
        ),
      );

      return service.fetchMetadata('https://example.com/article').then((meta) {
        expect(meta, isNotNull);
        expect(meta!.title, 'Test Title');
        expect(meta.description, 'Test Description');
        expect(meta.imageUrl, 'https://example.com/img.jpg');
        expect(meta.domain, 'example.com');
        expect(meta.url, 'https://example.com/article');
      });
    });

    test('parseHtml falls back to title tag when no OG title', () async {
      final service = LinkPreviewService(
        dio: _createMockDio(
          '<html><head><title>Page Title</title></head>'
          '<body></body></html>',
        ),
      );
      final meta = await service.fetchMetadata('https://example.com');
      expect(meta, isNotNull);
      expect(meta!.title, 'Page Title');
    });

    test('parseHtml falls back to meta description', () async {
      final service = LinkPreviewService(
        dio: _createMockDio(
          '<html><head>'
          '<title>Title</title>'
          '<meta name="description" content="Meta desc">'
          '</head><body></body></html>',
        ),
      );
      final meta = await service.fetchMetadata('https://example.com');
      expect(meta, isNotNull);
      expect(meta!.description, 'Meta desc');
    });

    test('parseHtml prefers OG title over page title', () async {
      final service = LinkPreviewService(
        dio: _createMockDio(
          '<html><head>'
          '<title>Page Title</title>'
          '<meta property="og:title" content="OG Title">'
          '</head><body></body></html>',
        ),
      );
      final meta = await service.fetchMetadata('https://example.com');
      expect(meta!.title, 'OG Title');
    });

    test('parseHtml prefers OG description over meta description', () async {
      final service = LinkPreviewService(
        dio: _createMockDio(
          '<html><head>'
          '<title>Title</title>'
          '<meta name="description" content="Meta desc">'
          '<meta property="og:description" content="OG desc">'
          '</head><body></body></html>',
        ),
      );
      final meta = await service.fetchMetadata('https://example.com');
      expect(meta!.description, 'OG desc');
    });

    test('parseHtml returns null when no title found', () async {
      final service = LinkPreviewService(
        dio: _createMockDio('<html><head></head><body></body></html>'),
      );
      final meta = await service.fetchMetadata('https://example.com');
      expect(meta, isNull);
    });

    test('parseHtml resolves relative image URL', () async {
      final service = LinkPreviewService(
        dio: _createMockDio(
          '<html><head>'
          '<title>Title</title>'
          '<meta property="og:image" content="/images/preview.jpg">'
          '</head><body></body></html>',
        ),
      );
      final meta = await service.fetchMetadata('https://example.com/page');
      expect(meta!.imageUrl, 'https://example.com/images/preview.jpg');
    });

    test('fetchMetadata returns null on non-200 status', () async {
      final service = LinkPreviewService(
        dio: _createMockDio('', statusCode: 404),
      );
      final meta = await service.fetchMetadata('https://example.com');
      expect(meta, isNull);
    });
  });
}

/// Creates a Dio instance with a mock adapter that returns [html] content.
Dio _createMockDio(String html, {int statusCode = 200}) {
  final dio = Dio();
  dio.httpClientAdapter = _MockAdapter(html, statusCode);
  return dio;
}

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.html, this.statusCode);

  final String html;
  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (statusCode != 200) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: statusCode,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(
      html,
      200,
      headers: {
        'content-type': ['text/html; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
