import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart'
    show conversationRepositoryProvider;
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

/// Status of an outbox message.
enum OutboxMessageStatus { pending, failed }

/// A message queued for sending when the device is offline.
@immutable
class OutboxMessage {
  const OutboxMessage({
    required this.localId,
    required this.content,
    required this.createdAt,
    this.replyToId,
    this.status = OutboxMessageStatus.pending,
    this.failureMessage,
    this.retryCount = 0,
  });

  final String localId;
  final String content;
  final DateTime createdAt;
  final String? replyToId;
  final OutboxMessageStatus status;
  final String? failureMessage;
  final int retryCount;

  OutboxMessage copyWith({
    OutboxMessageStatus? status,
    String? failureMessage,
    int? retryCount,
  }) {
    return OutboxMessage(
      localId: localId,
      content: content,
      createdAt: createdAt,
      replyToId: replyToId,
      status: status ?? this.status,
      failureMessage: failureMessage ?? this.failureMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        if (replyToId != null) 'replyToId': replyToId,
        'status': status.name,
        if (failureMessage != null) 'failureMessage': failureMessage,
        if (retryCount > 0) 'retryCount': retryCount,
      };

  factory OutboxMessage.fromJson(Map<String, dynamic> json) => OutboxMessage(
        localId: json['localId'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        replyToId: json['replyToId'] as String?,
        status: _parseStatus(json['status'] as String?),
        failureMessage: json['failureMessage'] as String?,
        retryCount: (json['retryCount'] as int?) ?? 0,
      );

  /// Parse status string with graceful fallback to [OutboxMessageStatus.pending]
  /// for unrecognized values. Prevents a single corrupt entry from discarding
  /// the entire outbox queue (#708).
  static OutboxMessageStatus _parseStatus(String? raw) {
    if (raw == null) return OutboxMessageStatus.pending;
    try {
      return OutboxMessageStatus.values.byName(raw);
    } catch (_) {
      return OutboxMessageStatus.pending;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutboxMessage &&
          runtimeType == other.runtimeType &&
          localId == other.localId &&
          content == other.content &&
          createdAt == other.createdAt &&
          replyToId == other.replyToId &&
          status == other.status &&
          failureMessage == other.failureMessage &&
          retryCount == other.retryCount;

  @override
  int get hashCode => Object.hash(
        localId,
        content,
        createdAt,
        replyToId,
        status,
        failureMessage,
        retryCount,
      );
}

/// State for the outbox store.
@immutable
class OutboxState {
  const OutboxState({this.items = const {}});

  /// Queued messages keyed by conversation target string.
  final Map<String, List<OutboxMessage>> items;

  OutboxState copyWith({Map<String, List<OutboxMessage>>? items}) {
    return OutboxState(items: items ?? this.items);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OutboxState || runtimeType != other.runtimeType) return false;
    if (items.length != other.items.length) return false;
    for (final entry in items.entries) {
      final otherList = other.items[entry.key];
      if (otherList == null || !listEquals(entry.value, otherList)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    final entryHashes = items.entries
        .map((entry) => Object.hash(entry.key, Object.hashAll(entry.value)))
        .toList()
      ..sort();
    return Object.hashAll(entryHashes);
  }

  /// All pending items across all conversations.
  List<OutboxMessage> pendingForTarget(String targetKey) {
    return items[targetKey]
            ?.where((m) => m.status == OutboxMessageStatus.pending)
            .toList() ??
        [];
  }

  /// All failed items for a specific conversation.
  List<OutboxMessage> failedForTarget(String targetKey) {
    return items[targetKey]
            ?.where((m) => m.status == OutboxMessageStatus.failed)
            .toList() ??
        [];
  }

  /// Count of failed items for a specific conversation.
  int failedCountForTarget(String targetKey) {
    return items[targetKey]
            ?.where((m) => m.status == OutboxMessageStatus.failed)
            .length ??
        0;
  }
}

/// Generate a stable key for a [ConversationDetailTarget].
///
/// Includes the surface type so DM and channel targets are distinguished
/// and can be reconstructed correctly from persistence.
String outboxTargetKey(ConversationDetailTarget target) {
  return '${target.surface.name}/${target.serverId.value}/${target.conversationId}';
}

/// Reconstruct a [ConversationDetailTarget] from a persisted target key.
ConversationDetailTarget? _targetFromKey(String key) {
  final parts = key.split('/');
  if (parts.length < 3) return null;
  final surface = parts[0];
  final serverId = parts[1];
  final conversationId = parts.sublist(2).join('/');
  switch (surface) {
    case 'channel':
      return ConversationDetailTarget.channel(
        ChannelScopeId(
          serverId: ServerScopeId(serverId),
          value: conversationId,
        ),
      );
    case 'directMessage':
      return ConversationDetailTarget.directMessage(
        DirectMessageScopeId(
          serverId: ServerScopeId(serverId),
          value: conversationId,
        ),
      );
    default:
      return null;
  }
}

const _prefsKey = 'outbox_queue';
const _maxConsecutiveDrainFailures = 3;

/// Initial backoff duration after consecutive drain failures.
/// Doubles on each subsequent failure, capped at [_maxDrainBackoffDuration].
@visibleForTesting
const initialDrainBackoffDuration = Duration(seconds: 5);

/// Maximum backoff duration — the cap for exponential growth.
@visibleForTesting
const maxDrainBackoffDuration = Duration(seconds: 300);

/// Maximum number of retry attempts per outbox item before marking it failed.
@visibleForTesting
const maxOutboxRetryAttempts = 5;

/// Maximum number of outbox messages per conversation target.
///
/// Prevents unbounded SharedPreferences growth when the device stays
/// offline for an extended period. Once a target's queue reaches this
/// limit, new enqueue attempts are rejected.
const maxOutboxItemsPerTarget = 50;

/// Callback type for notifying conversation stores about drain results.
///
/// Called after a successful send with the outbox local ID and server message,
/// or after a non-retryable failure with the local ID and failure.
typedef OutboxDrainCallback = void Function(
  ConversationDetailTarget target,
  String localId,
  ConversationMessageSummary? message,
  AppFailure? failure,
);

/// App-scoped store that manages the offline message outbox.
///
/// Messages are enqueued when the device is offline and drained
/// when connectivity is restored. The queue persists to
/// SharedPreferences so it survives app restart.
class OutboxStore extends Notifier<OutboxState> {
  int _localIdCounter = 0;
  bool _isDraining = false;
  int _consecutiveDrainFailures = 0;
  bool _drainBackoffActive = false;
  Timer? _drainBackoffTimer;
  Timer? _drainRescheduleTimer;
  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  final Map<String, OutboxDrainCallback> _drainCallbacks = {};

  @override
  bool updateShouldNotify(OutboxState previous, OutboxState next) =>
      previous != next;

  @override
  OutboxState build() {
    final state = _loadFromPrefs();
    _listenConnectivity();
    ref.onDispose(() {
      _connectivitySub?.cancel();
      _drainBackoffTimer?.cancel();
      _drainRescheduleTimer?.cancel();
    });
    // Drain any persisted outbox items on startup when already online.
    if (state.items.isNotEmpty) {
      final connectivity = ref.read(connectivityServiceProvider);
      if (connectivity.isOnline) {
        Future.microtask(() => drainAll());
      }
    }
    return state;
  }

  /// Register a callback for drain results on a specific target.
  ///
  /// The conversation detail store uses this to reconcile optimistic
  /// messages back into the conversation state.
  void registerDrainCallback(
    String targetKey,
    OutboxDrainCallback callback,
  ) {
    _drainCallbacks[targetKey] = callback;
  }

  /// Unregister the drain callback for a specific target.
  void unregisterDrainCallback(String targetKey) {
    _drainCallbacks.remove(targetKey);
  }

  /// Enqueue a message for later sending.
  ///
  /// If [localId] is provided, it is used as the outbox entry's local ID
  /// (allowing the caller to share the same ID with its optimistic message).
  ///
  /// Returns `true` if the message was enqueued successfully, or `false` if
  /// the per-target queue has reached [maxOutboxItemsPerTarget] capacity.
  ///
  /// Deduplicates:
  /// - Primary: if [localId] is provided and an existing entry with the same
  ///   localId exists, the enqueue is a no-op (#708 — prevents false-dedup
  ///   when two messages share content but have different localIds).
  /// - Fallback: if no [localId] is provided, deduplicates on content +
  ///   replyToId (legacy behavior for callers that don't supply an ID).
  bool enqueue(
    ConversationDetailTarget target,
    String content, {
    String? replyToId,
    String? localId,
  }) {
    final targetKey = outboxTargetKey(target);
    final existing = state.items[targetKey] ?? [];

    // Primary dedup: localId match (handles the race with localId assignment).
    // Checked before capacity so re-enqueue of an existing item is always safe.
    if (localId != null) {
      final hasLocalId = existing.any((m) => m.localId == localId);
      if (hasLocalId) return true; // already enqueued — not an error
    } else {
      // Fallback dedup: content + replyToId when no localId provided.
      final isDuplicate = existing.any(
        (m) =>
            m.status == OutboxMessageStatus.pending &&
            m.content == content &&
            m.replyToId == replyToId,
      );
      if (isDuplicate) return true; // already enqueued — not an error
    }

    // Capacity check: reject when the per-target queue is full.
    if (existing.length >= maxOutboxItemsPerTarget) return false;

    localId ??=
        'outbox-${++_localIdCounter}-${DateTime.now().millisecondsSinceEpoch}';
    final message = OutboxMessage(
      localId: localId,
      content: content,
      createdAt: DateTime.now(),
      replyToId: replyToId,
    );

    final current = Map<String, List<OutboxMessage>>.from(state.items);
    current[targetKey] = [...(current[targetKey] ?? []), message];
    state = state.copyWith(items: current);
    _persist();
    return true;
  }

  /// Remove a specific outbox item (e.g. user dismissed a failed message).
  void removeItem(ConversationDetailTarget target, String localId) {
    final targetKey = outboxTargetKey(target);
    final current = Map<String, List<OutboxMessage>>.from(state.items);
    final list = current[targetKey];
    if (list == null) return;
    current[targetKey] = list.where((m) => m.localId != localId).toList();
    if (current[targetKey]!.isEmpty) current.remove(targetKey);
    state = state.copyWith(items: current);
    _persist();
  }

  /// Retry a failed outbox item — reset its status to pending and retry count
  /// to 0, then trigger a drain.
  void retryItem(ConversationDetailTarget target, String localId) {
    final targetKey = outboxTargetKey(target);
    final current = Map<String, List<OutboxMessage>>.from(state.items);
    final list = current[targetKey];
    if (list == null) return;
    current[targetKey] = list.map((m) {
      if (m.localId == localId && m.status == OutboxMessageStatus.failed) {
        return m.copyWith(
          status: OutboxMessageStatus.pending,
          retryCount: 0,
        );
      }
      return m;
    }).toList();
    state = state.copyWith(items: current);
    _persist();
    _scheduleDrainIfNeeded();
  }

  /// Retry all failed outbox items for a specific conversation.
  void retryAllFailed(ConversationDetailTarget target) {
    final targetKey = outboxTargetKey(target);
    final current = Map<String, List<OutboxMessage>>.from(state.items);
    final list = current[targetKey];
    if (list == null) return;
    current[targetKey] = list.map((m) {
      if (m.status == OutboxMessageStatus.failed) {
        return m.copyWith(
          status: OutboxMessageStatus.pending,
          retryCount: 0,
        );
      }
      return m;
    }).toList();
    state = state.copyWith(items: current);
    _persist();
    _scheduleDrainIfNeeded();
  }

  /// Drain pending messages for a specific conversation.
  ///
  /// Sends messages FIFO. On retryable failure, increments retry count and
  /// stops draining (will retry on next connectivity event or backoff timer).
  /// If retry count exceeds [maxOutboxRetryAttempts], marks the item failed.
  /// On non-retryable failure, marks the item as failed immediately.
  Future<void> drain(ConversationDetailTarget target) async {
    final targetKey = outboxTargetKey(target);
    final repo = ref.read(conversationRepositoryProvider);
    final pending = state.pendingForTarget(targetKey);

    for (final item in pending) {
      try {
        final serverMessage = await repo.sendMessage(
          target,
          item.content,
          replyToId: item.replyToId,
        );
        // Success — remove from queue and notify callback.
        _clearDrainBackoff();
        _removeItem(targetKey, item.localId);
        _drainCallbacks[targetKey]
            ?.call(target, item.localId, serverMessage, null);
      } on AppFailure catch (e) {
        if (e.isRetryable) {
          // Increment retry count for this item.
          final newRetryCount = item.retryCount + 1;
          if (newRetryCount >= maxOutboxRetryAttempts) {
            // Max retries exceeded — mark as permanently failed.
            _updateItemStatus(
              targetKey,
              item.localId,
              OutboxMessageStatus.failed,
              failureMessage: e.message,
              retryCount: newRetryCount,
            );
            _drainCallbacks[targetKey]?.call(target, item.localId, null, e);
            continue; // Try next item in the queue.
          }
          // Still retryable — update count and stop draining.
          _updateItemRetryCount(targetKey, item.localId, newRetryCount);
          _recordDrainFailure();
          return;
        }
        // Non-retryable — mark as failed and notify callback.
        _updateItemStatus(
          targetKey,
          item.localId,
          OutboxMessageStatus.failed,
          failureMessage: e.message,
          retryCount: item.retryCount + 1,
        );
        _drainCallbacks[targetKey]?.call(target, item.localId, null, e);
      } catch (e) {
        // Catch-all for non-AppFailure exceptions (TypeError, FormatException,
        // RangeError, etc.) that would otherwise propagate unhandled and
        // permanently stall the drain loop (#850).
        _updateItemStatus(
          targetKey,
          item.localId,
          OutboxMessageStatus.failed,
          failureMessage: 'Unexpected error: $e',
          retryCount: item.retryCount + 1,
        );
        _drainCallbacks[targetKey]?.call(
          target,
          item.localId,
          null,
          UnknownFailure(message: 'Unexpected error: $e'),
        );
      }
    }
  }

  /// Drain all conversations.
  ///
  /// Re-checks connectivity before each target to avoid wasting attempts
  /// after a mid-drain network drop (#708).
  ///
  /// Re-entrancy safe: concurrent calls are rejected while a drain is active.
  /// After drain completes, re-schedules via Timer (not microtask) to yield
  /// control to the UI event loop and prevent spin-loop (#752).
  Future<void> drainAll() async {
    if (_isDraining || _drainBackoffActive) return;
    _isDraining = true;
    _drainRescheduleTimer?.cancel();
    _drainRescheduleTimer = null;
    try {
      // Snapshot keys before iterating (state may mutate).
      final keys = state.items.keys.toList();
      for (final key in keys) {
        // Re-check connectivity before each target — if the device went
        // offline mid-drain, stop early so remaining targets aren't attempted.
        final connectivity = ref.read(connectivityServiceProvider);
        if (!connectivity.isOnline) break;

        final target = _targetFromKey(key);
        if (target == null) continue;
        await drain(target);
      }
    } finally {
      _isDraining = false;
      // If still online with pending items, schedule a fresh drain via Timer
      // to yield control to the event loop. This prevents a recursive
      // microtask chain that would block the UI (#752).
      _scheduleDrainIfNeeded();
    }
  }

  /// Schedule a drain pass via Timer if there are pending items and no
  /// reschedule is already in flight. Uses 100ms delay to yield event loop.
  void _scheduleDrainIfNeeded() {
    if (_isDraining || _drainBackoffActive) return;
    if (_drainRescheduleTimer != null) return; // already scheduled

    final hasPending = state.items.values.any(
        (list) => list.any((m) => m.status == OutboxMessageStatus.pending));
    if (!hasPending) return;

    final connectivity = ref.read(connectivityServiceProvider);
    if (!connectivity.isOnline) return;

    _drainRescheduleTimer = Timer(const Duration(milliseconds: 100), () {
      _drainRescheduleTimer = null;
      drainAll();
    });
  }

  /// Clear all outbox items (memory + persistence).
  ///
  /// Called during logout to prevent previous user's queued messages from
  /// draining under the next user's session. Returns a [Future] so the
  /// caller can await durable removal of the persisted key.
  Future<void> clearAll() async {
    state = const OutboxState();
    try {
      await ref.read(sharedPreferencesProvider).remove(_prefsKey);
    } catch (_) {
      // Best-effort; ignore failures during cleanup.
    }
  }

  void _recordDrainFailure() {
    _consecutiveDrainFailures += 1;
    if (_consecutiveDrainFailures >= _maxConsecutiveDrainFailures) {
      _startDrainBackoff();
    }
  }

  /// Compute the exponential backoff duration for the current failure count.
  /// Starts at [initialDrainBackoffDuration], doubles each time, capped at
  /// [maxDrainBackoffDuration].
  @visibleForTesting
  Duration computeBackoffDuration() {
    // Exponent = number of times backoff has been triggered (starts at 0).
    final exponent = _consecutiveDrainFailures - _maxConsecutiveDrainFailures;
    final multiplier = 1 << exponent.clamp(0, 10); // 2^exponent, safe shift
    final backoffMs = initialDrainBackoffDuration.inMilliseconds * multiplier;
    final cappedMs = backoffMs.clamp(
      initialDrainBackoffDuration.inMilliseconds,
      maxDrainBackoffDuration.inMilliseconds,
    );
    return Duration(milliseconds: cappedMs);
  }

  void _startDrainBackoff() {
    if (_drainBackoffActive) return;
    _drainBackoffActive = true;
    _drainBackoffTimer?.cancel();
    final backoff = computeBackoffDuration();
    _drainBackoffTimer = Timer(backoff, () {
      _drainBackoffActive = false;
      _scheduleDrainIfNeeded();
    });
  }

  void _clearDrainBackoff() {
    _consecutiveDrainFailures = 0;
    _drainBackoffActive = false;
    _drainBackoffTimer?.cancel();
    _drainBackoffTimer = null;
  }

  void _removeItem(String targetKey, String localId) {
    final current = Map<String, List<OutboxMessage>>.from(state.items);
    final list = current[targetKey];
    if (list == null) return;
    current[targetKey] = list.where((m) => m.localId != localId).toList();
    if (current[targetKey]!.isEmpty) current.remove(targetKey);
    state = state.copyWith(items: current);
    _persist();
  }

  void _updateItemStatus(
    String targetKey,
    String localId,
    OutboxMessageStatus status, {
    String? failureMessage,
    int? retryCount,
  }) {
    final current = Map<String, List<OutboxMessage>>.from(state.items);
    final list = current[targetKey];
    if (list == null) return;
    current[targetKey] = list.map((m) {
      if (m.localId == localId) {
        return m.copyWith(
          status: status,
          failureMessage: failureMessage,
          retryCount: retryCount,
        );
      }
      return m;
    }).toList();
    state = state.copyWith(items: current);
    _persist();
  }

  /// Update only the retry count for an item (without changing status).
  void _updateItemRetryCount(
    String targetKey,
    String localId,
    int retryCount,
  ) {
    final current = Map<String, List<OutboxMessage>>.from(state.items);
    final list = current[targetKey];
    if (list == null) return;
    current[targetKey] = list.map((m) {
      if (m.localId == localId) {
        return m.copyWith(retryCount: retryCount);
      }
      return m;
    }).toList();
    state = state.copyWith(items: current);
    _persist();
  }

  void _listenConnectivity() {
    final service = ref.read(connectivityServiceProvider);
    _connectivitySub = service.statusStream.listen((status) {
      if (status == ConnectivityStatus.online) {
        _clearDrainBackoff();
        drainAll();
      }
    });
  }

  void _persist() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final map = <String, dynamic>{};
      for (final entry in state.items.entries) {
        map[entry.key] = entry.value.map((m) => m.toJson()).toList();
      }
      prefs.setString(_prefsKey, jsonEncode(map));
    } catch (_) {
      // Best-effort persistence; ignore failures.
    }
  }

  OutboxState _loadFromPrefs() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return const OutboxState();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = <String, List<OutboxMessage>>{};
      for (final entry in decoded.entries) {
        final list = (entry.value as List)
            .map((e) => OutboxMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) items[entry.key] = list;
      }
      return OutboxState(items: items);
    } catch (_) {
      return const OutboxState();
    }
  }
}

/// App-scoped provider for the outbox store.
final outboxStoreProvider = NotifierProvider<OutboxStore, OutboxState>(
  OutboxStore.new,
);
