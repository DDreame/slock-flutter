import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

final conversationDetailSessionStoreProvider =
    Provider<ConversationDetailSessionCache>((ref) {
  final cache = ConversationDetailSessionCache();
  ref.onDispose(() {
    cache.dispose();
  });
  return cache;
});

@immutable
class ConversationDetailSessionEntry {
  const ConversationDetailSessionEntry({
    required this.title,
    required this.messages,
    required this.historyLimited,
    required this.hasOlder,
    required this.scrollOffset,
    this.failedPendingMessages = const [],
    this.draft = '',
    this.replyToMessage,
    this.pendingAttachments = const [],
  });

  final String? title;
  final List<ConversationMessageSummary> messages;
  final bool historyLimited;
  final bool hasOlder;
  final double scrollOffset;

  /// Failed and queued pending messages preserved across session restore.
  final List<PendingMessage> failedPendingMessages;

  /// Composer draft text preserved across conversation switches.
  final String draft;

  /// Reply-to context preserved alongside the draft.
  final ConversationMessageSummary? replyToMessage;

  /// Pending attachment references preserved across conversation switches.
  final List<PendingAttachment> pendingAttachments;

  ConversationDetailState toState(ConversationDetailTarget target) {
    return ConversationDetailState(
      target: target,
      status: ConversationDetailStatus.success,
      title: title,
      messages: messages,
      pendingMessages: failedPendingMessages,
      historyLimited: historyLimited,
      hasOlder: hasOlder,
      draft: draft,
      replyToMessage: replyToMessage,
      pendingAttachments: pendingAttachments,
    );
  }

  ConversationDetailSessionEntry copyWith({
    String? title,
    List<ConversationMessageSummary>? messages,
    bool? historyLimited,
    bool? hasOlder,
    double? scrollOffset,
    List<PendingMessage>? failedPendingMessages,
    String? draft,
    ConversationMessageSummary? replyToMessage,
    bool clearReplyToMessage = false,
    List<PendingAttachment>? pendingAttachments,
  }) {
    return ConversationDetailSessionEntry(
      title: title ?? this.title,
      messages: messages ?? this.messages,
      historyLimited: historyLimited ?? this.historyLimited,
      hasOlder: hasOlder ?? this.hasOlder,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      failedPendingMessages:
          failedPendingMessages ?? this.failedPendingMessages,
      draft: draft ?? this.draft,
      replyToMessage:
          clearReplyToMessage ? null : (replyToMessage ?? this.replyToMessage),
      pendingAttachments: pendingAttachments ?? this.pendingAttachments,
    );
  }

  factory ConversationDetailSessionEntry.fromState(
    ConversationDetailState state, {
    required double scrollOffset,
  }) {
    return ConversationDetailSessionEntry(
      title: state.title,
      messages: state.messages,
      historyLimited: state.historyLimited,
      hasOlder: state.hasOlder,
      scrollOffset: scrollOffset,
      failedPendingMessages: state.pendingMessages
          .where((m) =>
              m.status == MessageSendStatus.failed ||
              m.status == MessageSendStatus.queued ||
              m.status == MessageSendStatus.sending)
          .map((m) => m.status == MessageSendStatus.sending
              ? m.copyWith(status: MessageSendStatus.queued)
              : m)
          .toList(growable: false),
      draft: state.draft,
      replyToMessage: state.replyToMessage,
      pendingAttachments: state.pendingAttachments,
    );
  }
}

/// Plain mutable cache for conversation session entries. Not a Riverpod
/// Notifier — mutations here do not trigger provider invalidation cascades,
/// making it safe to call from `ref.onDispose`.
class ConversationDetailSessionCache {
  /// Maximum number of cached session entries. Beyond this, oldest-accessed
  /// entries are evicted (LRU) to bound memory usage.
  static const maxEntries = 8;
  static const scrollOffsetDebounceDuration = Duration(milliseconds: 500);

  final _entries = <ConversationDetailTarget, ConversationDetailSessionEntry>{};
  Timer? _scrollOffsetDebounce;
  final _pendingScrollOffsets = <ConversationDetailTarget, double>{};

  /// Read a cached session entry by target.
  ConversationDetailSessionEntry? operator [](
          ConversationDetailTarget target) =>
      _entries[target];

  /// Number of cached entries.
  int get length => _entries.length;

  /// Whether the cache is empty.
  bool get isEmpty => _entries.isEmpty;

  /// All cached target keys (insertion order).
  Iterable<ConversationDetailTarget> get keys => _entries.keys;

  /// Whether a target has a cached entry.
  bool containsKey(ConversationDetailTarget target) =>
      _entries.containsKey(target);

  void saveSuccessState(
    ConversationDetailState detailState, {
    required double scrollOffset,
  }) {
    if (detailState.status != ConversationDetailStatus.success) {
      return;
    }
    // Remove existing entry so re-insertion moves it to "most recent" position.
    _entries.remove(detailState.target);
    _entries[detailState.target] = ConversationDetailSessionEntry.fromState(
      detailState,
      scrollOffset: scrollOffset,
    );
    // Evict oldest entries if over capacity.
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void saveScrollOffset(ConversationDetailTarget target, double scrollOffset) {
    if (!_entries.containsKey(target)) {
      return;
    }
    _pendingScrollOffsets[target] = scrollOffset;
    _scrollOffsetDebounce?.cancel();
    _scrollOffsetDebounce = Timer(
      scrollOffsetDebounceDuration,
      _flushPendingScrollOffsets,
    );
  }

  void _flushPendingScrollOffsets() {
    if (_pendingScrollOffsets.isEmpty) return;
    for (final entry in _pendingScrollOffsets.entries) {
      final existing = _entries[entry.key];
      if (existing != null) {
        _entries[entry.key] = existing.copyWith(scrollOffset: entry.value);
      }
    }
    _pendingScrollOffsets.clear();
  }

  /// Clears all session entries. Called on logout to prevent previous user's
  /// drafts from leaking into the next session.
  void clearAll() {
    _scrollOffsetDebounce?.cancel();
    _pendingScrollOffsets.clear();
    _entries.clear();
  }

  /// Cancel pending timers. Called from provider's onDispose.
  void dispose() {
    _scrollOffsetDebounce?.cancel();
    _pendingScrollOffsets.clear();
  }
}
