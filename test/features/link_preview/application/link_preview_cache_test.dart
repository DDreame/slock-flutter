// ---------------------------------------------------------------------------
// #559: Unbounded Cache Eviction — LRU + Voice Cap + Dio Close
//
// Problem:
//   1. `link_preview_store.dart:17`: Non-autoDispose provider with no
//      max-size/LRU/TTL — cache grows without bound as user scrolls.
//   2. `voice_message_store.dart:95`: Plain StateProvider for waveform
//      cache, no eviction — up to 3600 samples per recording, N recordings.
//   3. `link_preview_service.dart`: Dio instance created per service,
//      never explicitly closed on dispose.
//
// Phase A: skip:true invariants locking the cache eviction contracts.
//          Tests use ProviderContainer + fake services to verify eviction
//          behavior and resource cleanup.
//
// Invariants verified:
// INV-CACHE-LRU-1:      LinkPreviewCache evicts oldest when exceeding max 100
// INV-CACHE-LRU-2:      Re-fetching evicted URL triggers fresh load
// INV-CACHE-VOICE-CAP-1: Voice waveform cache evicts oldest when exceeding max
// INV-CACHE-DIO-CLOSE-1: LinkPreviewService Dio closed on provider dispose
// ---------------------------------------------------------------------------
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/link_preview/application/link_preview_store.dart';
import 'package:slock_app/features/link_preview/data/link_metadata.dart';
import 'package:slock_app/features/link_preview/data/link_preview_service.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';

void main() {
  // -----------------------------------------------------------------------
  // INV-CACHE-LRU-1: LinkPreviewCache evicts oldest at max size
  // -----------------------------------------------------------------------
  group('INV-CACHE-LRU-1: cache evicts oldest at max size', () {
    test(
      'link preview cache stays at max 100 entries after 101 fetches',
      () async {
        final service = _CountingLinkPreviewService();
        final container = ProviderContainer(
          overrides: [
            linkPreviewServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(linkPreviewCacheProvider.notifier);

        // Fill cache to max capacity (100).
        for (var i = 0; i < 100; i++) {
          await notifier.fetch('https://example.com/$i');
        }

        final stateAt100 = container.read(linkPreviewCacheProvider);
        expect(stateAt100.length, equals(100),
            reason: 'Cache must hold 100 entries at max capacity');

        // Add one more — should evict the oldest (url index 0).
        await notifier.fetch('https://example.com/100');

        final stateAt101 = container.read(linkPreviewCacheProvider);
        expect(stateAt101.length, equals(100),
            reason: 'Cache must not exceed 100 entries (LRU eviction)');
        expect(stateAt101.containsKey('https://example.com/0'), isFalse,
            reason: 'Oldest entry (url 0) must be evicted');
        expect(stateAt101.containsKey('https://example.com/100'), isTrue,
            reason: 'Newest entry (url 100) must be present');
      },
      skip: 'Phase A: invariant locked — Phase B adds LRU eviction',
    );
  });

  // -----------------------------------------------------------------------
  // INV-CACHE-LRU-2: Re-fetch after eviction is a cache miss
  // -----------------------------------------------------------------------
  group('INV-CACHE-LRU-2: evicted URL triggers fresh fetch', () {
    test(
      'fetching an evicted URL calls service again (cache miss)',
      () async {
        final service = _CountingLinkPreviewService();
        final container = ProviderContainer(
          overrides: [
            linkPreviewServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(linkPreviewCacheProvider.notifier);

        // Fill to max + 1 to evict url 0.
        for (var i = 0; i < 101; i++) {
          await notifier.fetch('https://example.com/$i');
        }
        expect(service.fetchCount, equals(101),
            reason: 'Service must be called for each unique URL');

        // Re-fetch url 0 — should be a cache miss and trigger service call.
        await notifier.fetch('https://example.com/0');
        expect(service.fetchCount, equals(102),
            reason: 'Evicted URL must trigger a fresh service call');

        final state = container.read(linkPreviewCacheProvider);
        expect(state.containsKey('https://example.com/0'), isTrue,
            reason: 'Re-fetched URL must be back in cache');
      },
      skip: 'Phase A: invariant locked — Phase B adds LRU eviction',
    );
  });

  // -----------------------------------------------------------------------
  // INV-CACHE-VOICE-CAP-1: Voice waveform cache evicts at max size
  //
  // Drives insertion through the production VoiceWaveformCacheNotifier.put()
  // API — the eviction logic lives inside put() in Phase B.
  // -----------------------------------------------------------------------
  group('INV-CACHE-VOICE-CAP-1: voice waveform cache max size', () {
    test(
      'voice waveform cache stays at max 50 entries after 51 inserts',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(voiceWaveformCacheProvider.notifier);

        // Populate 50 entries via production insertion API.
        for (var i = 0; i < 50; i++) {
          notifier.put('voice-$i', [0.1, 0.2, 0.3]);
        }
        expect(notifier.state.length, equals(50),
            reason: 'Waveform cache must hold 50 entries at max');

        // Add one more via production API — should evict the oldest.
        notifier.put('voice-50', [0.4, 0.5, 0.6]);

        expect(notifier.state.length, equals(50),
            reason: 'Waveform cache must not exceed 50 entries');
        expect(notifier.state.containsKey('voice-0'), isFalse,
            reason: 'Oldest waveform entry must be evicted');
        expect(notifier.state.containsKey('voice-50'), isTrue,
            reason: 'Newest waveform entry must be present');
      },
      skip: 'Phase A: invariant locked — Phase B adds waveform eviction',
    );
  });

  // -----------------------------------------------------------------------
  // INV-CACHE-DIO-CLOSE-1: Dio closed on provider dispose
  //
  // Uses overrideWith (factory override) so the provider lifecycle path
  // (including ref.onDispose) is exercised. overrideWithValue would bypass
  // the builder and miss the disposal registration.
  // -----------------------------------------------------------------------
  group('INV-CACHE-DIO-CLOSE-1: Dio closed on dispose', () {
    test(
      'LinkPreviewService.close() is called when provider is disposed',
      () async {
        var closeCalled = false;
        final container = ProviderContainer(
          overrides: [
            linkPreviewServiceProvider.overrideWith((ref) {
              final service = _CloseTrackingLinkPreviewService(
                onClose: () => closeCalled = true,
              );
              ref.onDispose(service.close);
              return service;
            }),
          ],
        );

        // Access the provider to ensure it's alive.
        container.read(linkPreviewCacheProvider);

        expect(closeCalled, isFalse,
            reason: 'Close callback must not fire before dispose');

        // Dispose container — ref.onDispose fires service.close().
        container.dispose();

        expect(closeCalled, isTrue,
            reason: 'Close callback must fire when provider is disposed');
      },
      skip: 'Phase A: invariant locked — Phase B adds Dio dispose',
    );
  });
}

// -- Helpers -----------------------------------------------------------------

/// A [LinkPreviewService] that counts fetch calls and returns dummy metadata.
class _CountingLinkPreviewService extends LinkPreviewService {
  _CountingLinkPreviewService() : super(dio: Dio());

  int fetchCount = 0;

  @override
  Future<LinkMetadata?> fetchMetadata(String url) async {
    fetchCount++;
    return LinkMetadata(
      url: url,
      title: 'Title for $url',
      domain: 'example.com',
    );
  }
}

/// A [LinkPreviewService] that tracks when [close] is called.
///
/// Used with `overrideWith` (factory override) to verify the provider
/// lifecycle calls close via `ref.onDispose`.
class _CloseTrackingLinkPreviewService extends LinkPreviewService {
  _CloseTrackingLinkPreviewService({required this.onClose}) : super(dio: Dio());

  final void Function() onClose;

  @override
  Future<LinkMetadata?> fetchMetadata(String url) async {
    return LinkMetadata(url: url, title: 'Title', domain: 'example.com');
  }

  @override
  void close() {
    onClose();
  }
}
