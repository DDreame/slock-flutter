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
/// - `AsyncError` on transient network failure (retryable on next access)
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
  /// On network error: caches `AsyncError` so the widget can render a
  /// fallback link. Errors are retryable — calling [fetch] again for the
  /// same URL will re-attempt the request.
  Future<void> fetch(String url) async {
    final existing = state[url];
    // Already succeeded or in progress — skip.
    if (existing is AsyncData || existing is AsyncLoading) return;

    // Mark as loading (overwrite any prior error).
    state = {...state, url: const AsyncValue.loading()};

    try {
      final metadata = await _service.fetchMetadata(url);
      state = {...state, url: AsyncValue.data(metadata)};
    } catch (e, st) {
      // Transient failure — store as error so widget can show fallback.
      state = {...state, url: AsyncValue.error(e, st)};
    }
  }

  /// Clear the entire cache.
  void clear() {
    state = {};
  }
}
