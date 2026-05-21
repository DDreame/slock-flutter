import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/link_preview/application/link_preview_store.dart';
import 'package:slock_app/features/link_preview/data/link_metadata.dart';
import 'package:slock_app/features/link_preview/data/link_preview_service.dart';

void main() {
  group('LinkPreviewCacheNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          linkPreviewServiceProvider.overrideWithValue(
            LinkPreviewService(
              dio: _createMockDio(
                '<html><head>'
                '<meta property="og:title" content="Test Page">'
                '<meta property="og:description" content="A test page">'
                '<meta property="og:image" content="https://example.com/img.jpg">'
                '</head><body></body></html>',
              ),
            ),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial cache is empty', () {
      final cache = container.read(linkPreviewCacheProvider);
      expect(cache, isEmpty);
    });

    test('fetch populates cache with metadata', () async {
      final notifier = container.read(linkPreviewCacheProvider.notifier);
      await notifier.fetch('https://example.com');

      final cache = container.read(linkPreviewCacheProvider);
      expect(cache, contains('https://example.com'));
      final value = cache['https://example.com']!;
      expect(value, isA<AsyncData<LinkMetadata?>>());
      final meta = value.value;
      expect(meta, isNotNull);
      expect(meta!.title, 'Test Page');
      expect(meta.description, 'A test page');
      expect(meta.imageUrl, 'https://example.com/img.jpg');
      expect(meta.domain, 'example.com');
    });

    test('fetch does not re-fetch already cached URL', () async {
      final notifier = container.read(linkPreviewCacheProvider.notifier);
      await notifier.fetch('https://example.com');
      final firstValue =
          container.read(linkPreviewCacheProvider)['https://example.com'];

      // Second fetch should not change the cache entry.
      await notifier.fetch('https://example.com');
      final secondValue =
          container.read(linkPreviewCacheProvider)['https://example.com'];

      expect(identical(firstValue, secondValue), isTrue);
    });

    test('concurrent fetches for same URL share one service request', () async {
      final service = _ControlledLinkPreviewService();
      final controlledContainer = ProviderContainer(
        overrides: [
          linkPreviewServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(controlledContainer.dispose);

      final notifier = controlledContainer.read(
        linkPreviewCacheProvider.notifier,
      );
      final firstFetch = notifier.fetch('https://example.com');
      final secondFetch = notifier.fetch('https://example.com');

      expect(service.calls, 1);

      service.complete(
        const LinkMetadata(
          url: 'https://example.com',
          title: 'Example',
          domain: 'example.com',
        ),
      );
      await Future.wait([firstFetch, secondFetch]);

      expect(service.calls, 1);
      expect(
        controlledContainer
            .read(linkPreviewCacheProvider)['https://example.com']
            ?.value
            ?.title,
        'Example',
      );
    });

    test('fetch stores null metadata when page has no OG tags', () async {
      final noTagsContainer = ProviderContainer(
        overrides: [
          linkPreviewServiceProvider.overrideWithValue(
            LinkPreviewService(
              dio: _createMockDio(
                '<html><head></head><body></body></html>',
              ),
            ),
          ),
        ],
      );
      addTearDown(noTagsContainer.dispose);

      final notifier = noTagsContainer.read(linkPreviewCacheProvider.notifier);
      await notifier.fetch('https://example.com');

      final cache = noTagsContainer.read(linkPreviewCacheProvider);
      expect(cache['https://example.com'], isA<AsyncData<LinkMetadata?>>());
      expect(cache['https://example.com']!.value, isNull);
    });

    test('fetch stores error on network failure and allows retry', () async {
      final failContainer = ProviderContainer(
        overrides: [
          linkPreviewServiceProvider.overrideWithValue(
            _FailingLinkPreviewService(),
          ),
        ],
      );
      addTearDown(failContainer.dispose);

      final notifier = failContainer.read(linkPreviewCacheProvider.notifier);
      await notifier.fetch('https://example.com');

      final cache = failContainer.read(linkPreviewCacheProvider);
      // Entry should be stored as error (so widget can show fallback).
      expect(cache.containsKey('https://example.com'), isTrue);
      expect(cache['https://example.com'], isA<AsyncError<LinkMetadata?>>());

      // Calling fetch again should retry (not skip).
      await notifier.fetch('https://example.com');
      // Still an error since the service keeps failing.
      expect(
          failContainer.read(linkPreviewCacheProvider)['https://example.com'],
          isA<AsyncError<LinkMetadata?>>());
    });

    test('multiple URLs are cached independently', () async {
      final notifier = container.read(linkPreviewCacheProvider.notifier);
      await notifier.fetch('https://a.com');
      await notifier.fetch('https://b.com');

      final cache = container.read(linkPreviewCacheProvider);
      expect(cache, hasLength(2));
      expect(cache, contains('https://a.com'));
      expect(cache, contains('https://b.com'));
    });

    test('clear empties the cache', () async {
      final notifier = container.read(linkPreviewCacheProvider.notifier);
      await notifier.fetch('https://example.com');
      expect(container.read(linkPreviewCacheProvider), isNotEmpty);

      notifier.clear();
      expect(container.read(linkPreviewCacheProvider), isEmpty);
    });
  });
}

/// Creates a Dio instance with a mock adapter that returns [html] content.
Dio _createMockDio(String html) {
  final dio = Dio();
  dio.httpClientAdapter = _MockAdapter(html);
  return dio;
}

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.html);

  final String html;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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

/// A [LinkPreviewService] that always throws.
class _FailingLinkPreviewService extends LinkPreviewService {
  _FailingLinkPreviewService() : super(dio: Dio());

  @override
  Future<LinkMetadata?> fetchMetadata(String url) async {
    throw Exception('Network error');
  }
}

class _ControlledLinkPreviewService extends LinkPreviewService {
  _ControlledLinkPreviewService() : super(dio: Dio());

  int calls = 0;
  final Completer<LinkMetadata?> _completer = Completer<LinkMetadata?>();

  @override
  Future<LinkMetadata?> fetchMetadata(String url) {
    calls += 1;
    return _completer.future;
  }

  void complete(LinkMetadata? metadata) {
    _completer.complete(metadata);
  }
}
