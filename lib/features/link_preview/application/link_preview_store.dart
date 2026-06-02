import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import '../data/link_metadata.dart';
import '../data/link_preview_service.dart';

/// Provider for the [LinkPreviewService] singleton.
///
/// Registers [LinkPreviewService.close] on dispose to release the
/// underlying Dio HTTP client when the provider is torn down.
final linkPreviewServiceProvider = Provider<LinkPreviewService>((ref) {
  final service = LinkPreviewService();
  ref.onDispose(service.close);
  return service;
});

/// In-memory cache of fetched link preview metadata.
///
/// Keyed by URL string. Values are:
/// - `AsyncLoading` while fetch is in progress
/// - `AsyncData(metadata)` on success (may be `null` if page has no OG tags)
/// - `AsyncError` on transient network failure (retryable on next access)
final linkPreviewCacheProvider = NotifierProvider<LinkPreviewCacheNotifier,
    Map<String, AsyncValue<LinkMetadata?>>>(
  LinkPreviewCacheNotifier.new,
);

/// Notifier that manages the link preview cache.
///
/// Uses LRU eviction: when the cache exceeds [maxSize] entries,
/// the least-recently-used entries are removed. Accessing an already-cached
/// URL via [fetch] refreshes its recency so it survives longer.
class LinkPreviewCacheNotifier
    extends Notifier<Map<String, AsyncValue<LinkMetadata?>>> {
  final Set<String> _inFlight = <String>{};

  /// Maximum number of cached link previews.
  static const maxSize = 100;

  @override
  Map<String, AsyncValue<LinkMetadata?>> build() {
    final service = ref.read(linkPreviewServiceProvider);
    ref.onDispose(service.close);
    return {};
  }

  /// Fetch metadata for [url] if not already cached or in progress.
  ///
  /// On cache hit (`AsyncData` or `AsyncLoading`), the entry is promoted
  /// to the most-recently-used position (LRU touch).
  ///
  /// On cache miss or `AsyncError` (retryable): fetches from service,
  /// caches the result, and trims to [maxSize] by evicting least-recently-used.
  Future<void> fetch(String url) async {
    final existing = state[url];
    // Already succeeded or in progress — promote to MRU and skip fetch.
    if (existing is AsyncData || existing is AsyncLoading) {
      _touch(url);
      return;
    }

    if (!_inFlight.add(url)) {
      _touch(url);
      return;
    }

    // Mark as loading (overwrite any prior error).
    state = _trimToMax(
      {...state, url: const AsyncValue.loading()},
      inFlight: _inFlight,
    );

    try {
      final service = ref.read(linkPreviewServiceProvider);
      final metadata = await service.fetchMetadata(url);
      state = _trimToMax(
        {...state, url: AsyncValue.data(metadata)},
        inFlight: _inFlight,
      );
    } on Exception catch (e, st) {
      ref
          .read(diagnosticsCollectorProvider)
          .error('LinkPreview', 'Metadata fetch failed for $url: $e');
      // Transient failure — store as error so widget can show fallback.
      state = _trimToMax(
        {...state, url: AsyncValue.error(e, st)},
        inFlight: _inFlight,
      );
    } finally {
      _inFlight.remove(url);
    }
  }

  /// Clear the entire cache.
  void clear() {
    _inFlight.clear();
    state = {};
  }

  /// Promotes [url] to the most-recently-used position.
  ///
  /// Removes and re-inserts the entry so it appears last in iteration
  /// order (Dart's [LinkedHashMap] preserves insertion order).
  void _touch(String url) {
    final value = state[url];
    if (value == null) return;
    final updated = Map<String, AsyncValue<LinkMetadata?>>.from(state)
      ..remove(url)
      ..[url] = value;
    state = updated;
  }

  /// Trims [cache] to [maxSize] by removing the least-recently-used entries.
  ///
  /// Dart's default Map (LinkedHashMap) preserves insertion order,
  /// so the first keys are the least recently used.
  static Map<String, AsyncValue<LinkMetadata?>> _trimToMax(
    Map<String, AsyncValue<LinkMetadata?>> cache, {
    Set<String> inFlight = const {},
  }) {
    while (cache.length > maxSize) {
      String? keyToRemove;
      for (final key in cache.keys) {
        if (!inFlight.contains(key)) {
          keyToRemove = key;
          break;
        }
      }
      if (keyToRemove == null) break;
      cache.remove(keyToRemove);
    }
    return cache;
  }
}
