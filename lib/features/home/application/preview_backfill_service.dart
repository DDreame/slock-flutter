import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';

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
  final client = ref.watch(appDioClientProvider);
  return (serverId, channelId) async {
    final response = await client.get<Object?>(
      '/messages/channel/$channelId',
      queryParameters: const {'limit': 1},
      options: Options(headers: {'X-Server-Id': serverId}),
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) return null;
    final messages = data['messages'] as List?;
    if (messages == null || messages.isEmpty) return null;
    final msg = messages.first as Map<String, dynamic>;
    final l10n = ref.read(appLocalizationsProvider);
    return PreviewFetchResult(
      messageId: msg['id'] as String? ?? '',
      preview: MessagePreviewResolver.resolve(
        l10n: l10n,
        content: msg['content'] as String?,
        messageType: msg['messageType'] as String? ?? msg['type'] as String?,
        isDeleted: msg['isDeleted'] as bool? ?? false,
        attachments: parseAttachments(msg['attachments']),
      ),
      activityAt: DateTime.tryParse(msg['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  };
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
  ///
  /// No-op if a backfill pass is already running.
  Future<void> backfill(
    List<HomeChannelSummary> channels, {
    Set<String> visibleChannelIds = const {},
  }) async {
    // Guard: only one backfill pass at a time.
    if (state.isRunning) return;

    // Filter to only channels missing previews.
    final needsBackfill =
        channels.where((c) => c.lastMessagePreview == null).toList();
    if (needsBackfill.isEmpty) return;

    state = PreviewBackfillState(
      isRunning: true,
      filled: Set<String>.of(state.filled),
    );

    final serverId = ref.read(activeServerScopeIdProvider);
    final filled = Set<String>.of(state.filled);

    // --- Phase 1: SQLite cache lookup ---
    final remainingAfterCache = <HomeChannelSummary>[];
    try {
      final localStore = ref.read(conversationLocalStoreProvider);
      final cached = await localStore.listConversationSummaries(
        serverId?.value ?? '',
        surface: 'channel',
      );

      // Index cached summaries by conversationId for O(1) lookup.
      final cacheMap = <String, LocalConversationSummaryRecord>{};
      for (final record in cached) {
        cacheMap[record.conversationId] = record;
      }

      final homeStore = ref.read(homeListStoreProvider.notifier);

      for (final channel in needsBackfill) {
        final id = channel.scopeId.value;
        final record = cacheMap[id];
        if (record != null &&
            record.lastMessagePreview != null &&
            record.lastMessagePreview!.isNotEmpty &&
            record.lastMessageId != null) {
          homeStore.backfillChannelPreview(
            conversationId: id,
            messageId: record.lastMessageId!,
            preview: record.lastMessagePreview!,
            activityAt: record.lastActivityAt ?? DateTime.now(),
          );
          filled.add(id);
        } else {
          remainingAfterCache.add(channel);
        }
      }
    } catch (_) {
      // If cache lookup fails, all channels go to Phase 2.
      remainingAfterCache
        ..clear()
        ..addAll(needsBackfill);
    }

    // --- Phase 2: Lazy-load from API with concurrency limiter ---
    if (remainingAfterCache.isNotEmpty && serverId != null) {
      final fetcher = ref.read(previewMessageFetcherProvider);

      // Sort: visible channels first, then remaining in original order.
      final sorted = <HomeChannelSummary>[
        ...remainingAfterCache
            .where((c) => visibleChannelIds.contains(c.scopeId.value)),
        ...remainingAfterCache
            .where((c) => !visibleChannelIds.contains(c.scopeId.value)),
      ];

      // Concurrency-limited fetch loop.
      var inFlight = 0;
      final pending = List<HomeChannelSummary>.of(sorted);

      Future<void> fetchOne(HomeChannelSummary channel) async {
        final id = channel.scopeId.value;
        try {
          final result = await fetcher(serverId.value, id);
          if (result != null) {
            ref.read(homeListStoreProvider.notifier).backfillChannelPreview(
                  conversationId: id,
                  messageId: result.messageId,
                  preview: result.preview,
                  activityAt: result.activityAt,
                );
            filled.add(id);
          }
        } catch (_) {
          // Silently skip failed fetches — best-effort backfill.
        }
      }

      // Process with concurrency cap.
      final allDone = Completer<void>();
      var nextIndex = 0;

      void pump() {
        while (inFlight < maxConcurrent && nextIndex < pending.length) {
          final channel = pending[nextIndex++];
          inFlight++;
          fetchOne(channel).whenComplete(() {
            inFlight--;
            if (nextIndex >= pending.length && inFlight == 0) {
              if (!allDone.isCompleted) allDone.complete();
            } else {
              pump();
            }
          });
        }
        if (pending.isEmpty && inFlight == 0 && !allDone.isCompleted) {
          allDone.complete();
        }
      }

      pump();
      await allDone.future;
    }

    state = PreviewBackfillState(isRunning: false, filled: filled);
  }
}

final previewBackfillServiceProvider =
    NotifierProvider<PreviewBackfillService, PreviewBackfillState>(
  PreviewBackfillService.new,
);
