import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/link_metadata.dart';
import '../data/link_preview_service.dart';

/// Provider for the [LinkPreviewService] singleton.
final linkPreviewServiceProvider = Provider<LinkPreviewService>((ref) {
  return LinkPreviewService();
});

/// In-memory cache of fetched link preview metadata.
///
/// Keyed by URL string. Values are:
/// - `AsyncLoading` while fetch is in progress
/// - `AsyncData(metadata)` on success (may be `null` if page has no OG tags)
///
/// Transient network errors are NOT cached — the entry is removed so
/// the next scroll/rebuild can retry.
final linkPreviewCacheProvider = StateNotifierProvider<LinkPreviewCacheNotifier,
    Map<String, AsyncValue<LinkMetadata?>>>((ref) {
  return LinkPreviewCacheNotifier(ref.watch(linkPreviewServiceProvider));
});

/// Notifier that manages the link preview cache.
class LinkPreviewCacheNotifier
    extends StateNotifier<Map<String, AsyncValue<LinkMetadata?>>> {
  LinkPreviewCacheNotifier(this._service) : super({});

  final LinkPreviewService _service;

  /// Fetch metadata for [url] if not already cached or in progress.
  ///
  /// On success: caches `AsyncData(metadata)` (may be null if no OG tags).
  /// On network error: removes the loading entry so retry is possible.
  Future<void> fetch(String url) async {
    // Already fetched or in progress.
    if (state.containsKey(url)) return;

    // Mark as loading.
    state = {...state, url: const AsyncValue.loading()};

    try {
      final metadata = await _service.fetchMetadata(url);
      state = {...state, url: AsyncValue.data(metadata)};
    } catch (_) {
      // Transient failure — remove the entry so next access retries.
      final updated = Map<String, AsyncValue<LinkMetadata?>>.of(state);
      updated.remove(url);
      state = updated;
    }
  }

  /// Clear the entire cache.
  void clear() {
    state = {};
  }
}
