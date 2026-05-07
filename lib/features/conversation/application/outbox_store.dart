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
  });

  final String localId;
  final String content;
  final DateTime createdAt;
  final String? replyToId;
  final OutboxMessageStatus status;
  final String? failureMessage;

  OutboxMessage copyWith({
    OutboxMessageStatus? status,
    String? failureMessage,
  }) {
    return OutboxMessage(
      localId: localId,
      content: content,
      createdAt: createdAt,
      replyToId: replyToId,
      status: status ?? this.status,
      failureMessage: failureMessage ?? this.failureMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        if (replyToId != null) 'replyToId': replyToId,
        'status': status.name,
        if (failureMessage != null) 'failureMessage': failureMessage,
      };

  factory OutboxMessage.fromJson(Map<String, dynamic> json) => OutboxMessage(
        localId: json['localId'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        replyToId: json['replyToId'] as String?,
        status: OutboxMessageStatus.values.byName(
          json['status'] as String? ?? 'pending',
        ),
        failureMessage: json['failureMessage'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutboxMessage &&
          runtimeType == other.runtimeType &&
          localId == other.localId;

  @override
  int get hashCode => localId.hashCode;
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

  /// All pending items across all conversations.
  List<OutboxMessage> pendingForTarget(String targetKey) {
    return items[targetKey]
            ?.where((m) => m.status == OutboxMessageStatus.pending)
            .toList() ??
        [];
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
  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  final Map<String, OutboxDrainCallback> _drainCallbacks = {};

  @override
  OutboxState build() {
    final state = _loadFromPrefs();
    _listenConnectivity();
    ref.onDispose(() => _connectivitySub?.cancel());
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
  /// Deduplicates: if the target already has a pending message with the
  /// same content and replyToId, the enqueue is a no-op.
  void enqueue(
    ConversationDetailTarget target,
    String content, {
    String? replyToId,
    String? localId,
  }) {
    final targetKey = outboxTargetKey(target);

    // Deduplicate: skip if same content + replyToId already pending.
    final existing = state.items[targetKey] ?? [];
    final isDuplicate = existing.any(
      (m) =>
          m.status == OutboxMessageStatus.pending &&
          m.content == content &&
          m.replyToId == replyToId,
    );
    if (isDuplicate) return;

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

  /// Drain pending messages for a specific conversation.
  ///
  /// Sends messages FIFO. On retryable failure, stops draining (will retry
  /// on next connectivity event). On non-retryable failure, marks the item
  /// as failed, notifies the callback, and continues.
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
        _removeItem(targetKey, item.localId);
        _drainCallbacks[targetKey]
            ?.call(target, item.localId, serverMessage, null);
      } on AppFailure catch (e) {
        if (e.isRetryable) {
          // Network/timeout — stop draining, will retry later.
          return;
        }
        // Non-retryable — mark as failed and notify callback.
        _updateItemStatus(
          targetKey,
          item.localId,
          OutboxMessageStatus.failed,
          failureMessage: e.message,
        );
        _drainCallbacks[targetKey]?.call(target, item.localId, null, e);
      }
    }
  }

  /// Drain all conversations.
  Future<void> drainAll() async {
    // Snapshot keys before iterating (state may mutate).
    final keys = state.items.keys.toList();
    for (final key in keys) {
      final target = _targetFromKey(key);
      if (target == null) continue;
      await drain(target);
    }
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
  }) {
    final current = Map<String, List<OutboxMessage>>.from(state.items);
    final list = current[targetKey];
    if (list == null) return;
    current[targetKey] = list.map((m) {
      if (m.localId == localId) {
        return m.copyWith(status: status, failureMessage: failureMessage);
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
