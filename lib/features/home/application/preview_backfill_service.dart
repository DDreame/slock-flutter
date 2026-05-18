import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:slock_app/features/home/data/home_repository.dart';

// ---------------------------------------------------------------------------
// #567: Channel/Inbox Preview Backfill
//
// Two-phase backfill: (1) check SQLite cache for previews, (2) lazy-load
// from API for remaining nulls. Concurrency-limited, viewport-prioritized.
// ---------------------------------------------------------------------------

/// State exposed by the backfill service.
class PreviewBackfillState {
  const PreviewBackfillState({
    this.isRunning = false,
    this.filled = const {},
  });

  /// Whether a backfill pass is currently in progress.
  final bool isRunning;

  /// Channel IDs that have been successfully backfilled.
  final Set<String> filled;
}

/// Result of fetching the last message for a single channel.
class PreviewFetchResult {
  const PreviewFetchResult({
    required this.messageId,
    required this.preview,
    required this.activityAt,
  });

  final String messageId;
  final String preview;
  final DateTime activityAt;
}

/// Signature for the single-channel message fetcher used by backfill Phase 2.
///
/// Given a server scope ID and channel ID, fetches the latest message and
/// returns a [PreviewFetchResult], or null if no messages exist.
typedef PreviewMessageFetcher = Future<PreviewFetchResult?> Function(
  String serverId,
  String channelId,
);

/// Injectable provider for the single-message fetch function.
///
/// In production, wired to `GET /messages/channel/{id}?limit=1`.
/// In tests, override with a fake that records calls and controls timing.
final previewMessageFetcherProvider = Provider<PreviewMessageFetcher>((ref) {
  // Phase B: wire to actual API call.
  return (serverId, channelId) async => null;
});

/// Service that fills missing lastMessagePreview values for channels.
///
/// Phase 1: Check ConversationLocalStore for cached previews.
/// Phase 2: For remaining nulls, use [previewMessageFetcherProvider] to fetch
/// `GET /messages/channel/{id}?limit=1` with a concurrency limiter
/// (max 5 simultaneous requests).
///
/// Accepts an optional [visibleChannelIds] set to prioritize visible channels.
class PreviewBackfillService extends Notifier<PreviewBackfillState> {
  /// Maximum concurrent lazy-load API requests.
  int get maxConcurrent => 5;

  @override
  PreviewBackfillState build() => const PreviewBackfillState();

  /// Run the backfill for [channels] with null lastMessagePreview.
  ///
  /// [visibleChannelIds] — IDs of channels currently in the viewport;
  /// these are loaded first (priority ordering).
  Future<void> backfill(
    List<HomeChannelSummary> channels, {
    Set<String> visibleChannelIds = const {},
  }) async {
    // Phase B implementation.
  }
}

final previewBackfillServiceProvider =
    NotifierProvider<PreviewBackfillService, PreviewBackfillState>(
  PreviewBackfillService.new,
);
