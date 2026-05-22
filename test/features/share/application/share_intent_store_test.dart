import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:slock_app/features/share/application/share_intent_store.dart';
import 'package:slock_app/features/share/data/shared_content.dart';

void main() {
  group('parseSharedMedia', () {
    test('returns empty SharedContent for empty list', () {
      final result = parseSharedMedia([]);
      expect(result.isEmpty, isTrue);
    });

    test('maps single text SharedMediaFile', () {
      final result = parseSharedMedia([
        SharedMediaFile(path: 'Hello world', type: SharedMediaType.text),
      ]);
      expect(result.items, hasLength(1));
      expect(result.items[0].type, SharedContentType.text);
      expect(result.items[0].path, 'Hello world');
    });

    test('maps single image SharedMediaFile with mimeType', () {
      final result = parseSharedMedia([
        SharedMediaFile(
          path: '/tmp/photo.jpg',
          type: SharedMediaType.image,
          mimeType: 'image/jpeg',
        ),
      ]);
      expect(result.items, hasLength(1));
      expect(result.items[0].type, SharedContentType.image);
      expect(result.items[0].path, '/tmp/photo.jpg');
      expect(result.items[0].mimeType, 'image/jpeg');
    });

    test('maps multiple SharedMediaFiles', () {
      final result = parseSharedMedia([
        SharedMediaFile(
          path: '/tmp/photo1.jpg',
          type: SharedMediaType.image,
          mimeType: 'image/jpeg',
        ),
        SharedMediaFile(
          path: '/tmp/photo2.png',
          type: SharedMediaType.image,
          mimeType: 'image/png',
        ),
        SharedMediaFile(
          path: 'Check out these photos',
          type: SharedMediaType.text,
        ),
      ]);
      expect(result.items, hasLength(3));
      expect(result.items[0].type, SharedContentType.image);
      expect(result.items[1].type, SharedContentType.image);
      expect(result.items[2].type, SharedContentType.text);
    });

    test('maps url type', () {
      final result = parseSharedMedia([
        SharedMediaFile(
          path: 'https://example.com',
          type: SharedMediaType.url,
        ),
      ]);
      expect(result.items[0].type, SharedContentType.url);
      expect(result.items[0].path, 'https://example.com');
    });

    test('maps video with thumbnail', () {
      final result = parseSharedMedia([
        SharedMediaFile(
          path: '/tmp/video.mp4',
          type: SharedMediaType.video,
          mimeType: 'video/mp4',
          thumbnail: '/tmp/thumb.jpg',
        ),
      ]);
      expect(result.items[0].type, SharedContentType.video);
      expect(result.items[0].thumbnail, '/tmp/thumb.jpg');
    });

    test('maps file type', () {
      final result = parseSharedMedia([
        SharedMediaFile(
          path: '/tmp/doc.pdf',
          type: SharedMediaType.file,
          mimeType: 'application/pdf',
        ),
      ]);
      expect(result.items[0].type, SharedContentType.file);
      expect(result.items[0].mimeType, 'application/pdf');
    });
  });

  group('ShareIntentStore', () {
    late ProviderContainer container;
    late StreamController<List<SharedMediaFile>> mediaStreamController;

    setUp(() {
      mediaStreamController =
          StreamController<List<SharedMediaFile>>.broadcast();

      ReceiveSharingIntent.setMockValues(
        initialMedia: [],
        mediaStream: mediaStreamController.stream,
      );

      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
      mediaStreamController.close();
    });

    test('initial state is null', () {
      expect(container.read(shareIntentStoreProvider), isNull);
    });

    test('initialize picks up cold-start media', () async {
      container.dispose();

      ReceiveSharingIntent.setMockValues(
        initialMedia: [
          SharedMediaFile(path: 'Hello', type: SharedMediaType.text),
        ],
        mediaStream: mediaStreamController.stream,
      );

      container = ProviderContainer();
      await container.read(shareIntentStoreProvider.notifier).initialize();

      final state = container.read(shareIntentStoreProvider);
      expect(state, isNotNull);
      expect(state!.items, hasLength(1));
      expect(state.items[0].type, SharedContentType.text);
      expect(state.items[0].path, 'Hello');
    });

    test('initialize subscribes to foreground media stream', () async {
      await container.read(shareIntentStoreProvider.notifier).initialize();

      expect(container.read(shareIntentStoreProvider), isNull);

      mediaStreamController.add([
        SharedMediaFile(
          path: '/tmp/photo.jpg',
          type: SharedMediaType.image,
          mimeType: 'image/jpeg',
        ),
      ]);

      // Allow microtask to process.
      await Future<void>.delayed(Duration.zero);

      final state = container.read(shareIntentStoreProvider);
      expect(state, isNotNull);
      expect(state!.items, hasLength(1));
      expect(state.items[0].type, SharedContentType.image);
    });

    test('empty stream events are ignored', () async {
      await container.read(shareIntentStoreProvider.notifier).initialize();

      mediaStreamController.add([]);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(shareIntentStoreProvider), isNull);
    });

    test('consume clears state', () async {
      container.dispose();

      ReceiveSharingIntent.setMockValues(
        initialMedia: [
          SharedMediaFile(path: 'test', type: SharedMediaType.text),
        ],
        mediaStream: mediaStreamController.stream,
      );

      container = ProviderContainer();
      await container.read(shareIntentStoreProvider.notifier).initialize();

      expect(container.read(shareIntentStoreProvider), isNotNull);

      container.read(shareIntentStoreProvider.notifier).consume();

      expect(container.read(shareIntentStoreProvider), isNull);
    });

    test('dispose during initialize does not write cold-start state', () async {
      final delayedIntent = _DelayedReceiveSharingIntent(
        mediaStream: mediaStreamController.stream,
      );
      ReceiveSharingIntent.instance = delayedIntent;

      final notifier = container.read(shareIntentStoreProvider.notifier);
      final initializeFuture = notifier.initialize();

      container.dispose();
      delayedIntent.initialMediaCompleter.complete([
        SharedMediaFile(path: 'late', type: SharedMediaType.text),
      ]);

      await initializeFuture;

      expect(
        mediaStreamController.hasListener,
        isFalse,
        reason: 'Disposed initialize must not subscribe after getInitialMedia.',
      );
    });

    test('multiple stream events update state to latest', () async {
      await container.read(shareIntentStoreProvider.notifier).initialize();

      mediaStreamController.add([
        SharedMediaFile(path: 'first', type: SharedMediaType.text),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(shareIntentStoreProvider)!.items[0].path, 'first');

      mediaStreamController.add([
        SharedMediaFile(path: 'second', type: SharedMediaType.text),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(shareIntentStoreProvider)!.items[0].path, 'second');
    });
  });
}

class _DelayedReceiveSharingIntent extends ReceiveSharingIntent {
  _DelayedReceiveSharingIntent({required this.mediaStream});

  final Stream<List<SharedMediaFile>> mediaStream;
  final Completer<List<SharedMediaFile>> initialMediaCompleter =
      Completer<List<SharedMediaFile>>();

  @override
  Future<List<SharedMediaFile>> getInitialMedia() =>
      initialMediaCompleter.future;

  @override
  Stream<List<SharedMediaFile>> getMediaStream() => mediaStream;

  @override
  Future<dynamic> reset() async {}
}
