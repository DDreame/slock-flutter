import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
    test('fetchMetadata throws on network error', () async {
      // Use a Dio with a bad base URL to simulate failure.
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(milliseconds: 100),
        receiveTimeout: const Duration(milliseconds: 100),
      ));
      final service = LinkPreviewService(dio: dio);
      expect(
        () => service.fetchMetadata('https://nonexistent.invalid'),
        throwsA(isA<DioException>()),
      );
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

    test('fetchMetadata reads at most 256KB while parsing head metadata',
        () async {
      const head = '<html><head>'
          '<meta property="og:title" content="Capped Title">'
          '<meta property="og:description" content="Head metadata">'
          '</head><body>';
      final adapter = _ChunkedMockAdapter(
        utf8.encode(head.padRight(4096, ' ')),
        List<int>.filled(1024 * 1024, 65),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final service = LinkPreviewService(dio: dio);

      final meta = await service.fetchMetadata('https://example.com/large');

      expect(meta, isNotNull);
      expect(meta!.title, 'Capped Title');
      expect(meta.description, 'Head metadata');
      expect(adapter.bytesEmitted,
          lessThanOrEqualTo(LinkPreviewService.maxPreviewHtmlBytes));
    });

    test('fetchMetadata throws on non-200 status', () async {
      final service = LinkPreviewService(
        dio: _createMockDio('', statusCode: 404),
      );
      expect(
        () => service.fetchMetadata('https://example.com'),
        throwsA(isA<DioException>()),
      );
    });

    test(
        'fetchMetadata drains stream before returning null on non-200 response',
        () async {
      final body = _DrainTrackingResponseBody(statusCode: 404);
      final service = LinkPreviewService(dio: _createResponseDio(body));

      final meta = await service.fetchMetadata('https://example.com/missing');

      expect(meta, isNull);
      expect(body.wasListened, isTrue);
      expect(body.wasDrained, isTrue);
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

class _ChunkedMockAdapter implements HttpClientAdapter {
  _ChunkedMockAdapter(this.headBytes, this.tailBytes);

  final List<int> headBytes;
  final List<int> tailBytes;
  int bytesEmitted = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    late StreamController<Uint8List> controller;
    var offset = 0;
    controller = StreamController<Uint8List>(
      onListen: () {
        controller.add(Uint8List.fromList(headBytes));
        bytesEmitted += headBytes.length;
        Timer.periodic(Duration.zero, (timer) {
          if (controller.isClosed) {
            timer.cancel();
            return;
          }
          if (offset >= tailBytes.length) {
            timer.cancel();
            unawaited(controller.close());
            return;
          }
          final end = (offset + 4096).clamp(0, tailBytes.length);
          final chunk = tailBytes.sublist(offset, end);
          offset = end;
          bytesEmitted += chunk.length;
          controller.add(Uint8List.fromList(chunk));
        });
      },
    );

    return ResponseBody(
      controller.stream,
      200,
      headers: {
        'content-type': ['text/html; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _createResponseDio(ResponseBody body) {
  final dio = Dio(
    BaseOptions(validateStatus: (_) => true),
  );
  dio.httpClientAdapter = _ResponseAdapter(body);
  return dio;
}

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter(this.body);

  final ResponseBody body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return body;
  }

  @override
  void close({bool force = false}) {}
}

class _DrainTrackingResponseBody extends ResponseBody {
  _DrainTrackingResponseBody({required int statusCode})
      : super(
          _trackingStream(),
          statusCode,
          headers: {
            'content-type': ['text/html; charset=utf-8'],
          },
        );

  bool wasListened = false;
  bool wasDrained = false;

  static Stream<Uint8List> _trackingStream() async* {
    yield Uint8List.fromList(utf8.encode('<html></html>'));
  }

  @override
  Stream<Uint8List> get stream {
    wasListened = true;
    return super.stream.map((chunk) {
      wasDrained = true;
      return Uint8List.fromList(chunk);
    });
  }
}
