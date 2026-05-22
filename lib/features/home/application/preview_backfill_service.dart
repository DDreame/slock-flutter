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

  /// Re-entrancy guard for DM backfill (#741).
  Completer<void>? _dmBackfillInFlight;

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

    try {
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

        for (final channel in needsBackfill) {
          final id = channel.scopeId.value;
          final record = cacheMap[id];
          if (record != null &&
              record.lastMessagePreview != null &&
              record.lastMessagePreview!.isNotEmpty &&
              record.lastMessageId != null) {
            ref.read(homeListStoreProvider.notifier).backfillChannelPreview(
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
      } catch (e, st) {
        // If cache lookup fails, all channels go to Phase 2.
        try {
          ref.read(diagnosticsCollectorProvider).error(
            'PreviewBackfill',
            'Channel cache lookup failed: $e',
            metadata: {'stackTrace': '$st'},
          );
        } catch (_) {
          // Container disposed — skip telemetry.
        }
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
          } catch (e, st) {
            try {
              ref.read(diagnosticsCollectorProvider).error(
                'PreviewBackfill',
                'Channel fetch failed for $id: $e',
                metadata: {'stackTrace': '$st'},
              );
            } catch (_) {
              // Container disposed during async backfill — skip telemetry.
            }
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
    } finally {
      state = PreviewBackfillState(isRunning: false, filled: filled);
    }
  }

  /// BUG-1 fix (#637): Backfill missing previews for DMs.
  ///
  /// Mirrors [backfill] but operates on [HomeDirectMessageSummary] and calls
  /// [HomeListStore.backfillDmPreview] instead of backfillChannelPreview.
  /// Guarded against re-entrancy (#741): concurrent calls await the in-flight
  /// pass instead of starting a duplicate.
  Future<void> backfillDirectMessages(
    List<HomeDirectMessageSummary> directMessages,
  ) async {
    // Re-entrancy guard: if already running, await existing pass.
    if (_dmBackfillInFlight != null) {
      await _dmBackfillInFlight!.future;
      return;
    }

    final needsBackfill =
        directMessages.where((d) => d.lastMessagePreview == null).toList();
    if (needsBackfill.isEmpty) return;

    _dmBackfillInFlight = Completer<void>();
    try {
      await _backfillDirectMessagesImpl(needsBackfill);
    } finally {
      final completer = _dmBackfillInFlight!;
      _dmBackfillInFlight = null;
      completer.complete();
    }
  }

  Future<void> _backfillDirectMessagesImpl(
    List<HomeDirectMessageSummary> needsBackfill,
  ) async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    // --- Phase 1: SQLite cache lookup ---
    final remainingAfterCache = <HomeDirectMessageSummary>[];
    try {
      final localStore = ref.read(conversationLocalStoreProvider);
      final cached = await localStore.listConversationSummaries(
        serverId.value,
        surface: 'direct_message',
      );

      final cacheMap = <String, LocalConversationSummaryRecord>{};
      for (final record in cached) {
        cacheMap[record.conversationId] = record;
      }

      final homeStore = ref.read(homeListStoreProvider.notifier);

      for (final dm in needsBackfill) {
        final id = dm.scopeId.value;
        final record = cacheMap[id];
        if (record != null &&
            record.lastMessagePreview != null &&
            record.lastMessagePreview!.isNotEmpty &&
            record.lastMessageId != null) {
          homeStore.backfillDmPreview(
            conversationId: id,
            messageId: record.lastMessageId!,
            preview: record.lastMessagePreview!,
            activityAt: record.lastActivityAt ?? DateTime.now(),
          );
        } else {
          remainingAfterCache.add(dm);
        }
      }
    } catch (e, st) {
      try {
        ref.read(diagnosticsCollectorProvider).error(
          'PreviewBackfill',
          'DM cache lookup failed: $e',
          metadata: {'stackTrace': '$st'},
        );
      } catch (_) {
        // Container disposed — skip telemetry.
      }
      remainingAfterCache
        ..clear()
        ..addAll(needsBackfill);
    }

    // --- Phase 2: Lazy-load from API ---
    if (remainingAfterCache.isEmpty) return;

    final fetcher = ref.read(previewMessageFetcherProvider);
    final homeStore = ref.read(homeListStoreProvider.notifier);

    Future<void> fetchOne(HomeDirectMessageSummary dm) async {
      final id = dm.scopeId.value;
      try {
        final result = await fetcher(serverId.value, id);
        if (result != null) {
          homeStore.backfillDmPreview(
            conversationId: id,
            messageId: result.messageId,
            preview: result.preview,
            activityAt: result.activityAt,
          );
        }
      } catch (e, st) {
        try {
          ref.read(diagnosticsCollectorProvider).error(
            'PreviewBackfill',
            'DM fetch failed for $id: $e',
            metadata: {'stackTrace': '$st'},
          );
        } catch (_) {
          // Container disposed during async backfill — skip telemetry.
        }
      }
    }

    // Concurrency-limited fetch loop (same cap as channel backfill).
    final allDone = Completer<void>();
    var nextIndex = 0;
    var inFlight = 0;
    final pending = List<HomeDirectMessageSummary>.of(remainingAfterCache);

    void pump() {
      while (inFlight < maxConcurrent && nextIndex < pending.length) {
        final dm = pending[nextIndex++];
        inFlight++;
        fetchOne(dm).whenComplete(() {
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
}

final previewBackfillServiceProvider =
    NotifierProvider<PreviewBackfillService, PreviewBackfillState>(
  PreviewBackfillService.new,
);
