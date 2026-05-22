import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

final conversationDetailSessionStoreProvider = NotifierProvider<
    ConversationDetailSessionStore,
    Map<ConversationDetailTarget, ConversationDetailSessionEntry>>(
  ConversationDetailSessionStore.new,
);

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
    );
  }
}

class ConversationDetailSessionStore extends Notifier<
    Map<ConversationDetailTarget, ConversationDetailSessionEntry>> {
  /// Maximum number of cached session entries. Beyond this, oldest-accessed
  /// entries are evicted (LRU) to bound memory usage.
  static const maxEntries = 8;
  static const scrollOffsetDebounceDuration = Duration(milliseconds: 500);

  Timer? _scrollOffsetDebounce;
  final Map<ConversationDetailTarget, double> _pendingScrollOffsets = {};

  @override
  Map<ConversationDetailTarget, ConversationDetailSessionEntry> build() {
    ref.onDispose(() {
      _scrollOffsetDebounce?.cancel();
      _pendingScrollOffsets.clear();
    });
    return const {};
  }

  void saveSuccessState(
    ConversationDetailState detailState, {
    required double scrollOffset,
  }) {
    if (detailState.status != ConversationDetailStatus.success) {
      return;
    }
    final updated =
        Map<ConversationDetailTarget, ConversationDetailSessionEntry>.from(
            state);
    // Remove existing entry so re-insertion moves it to "most recent" position.
    updated.remove(detailState.target);
    updated[detailState.target] = ConversationDetailSessionEntry.fromState(
      detailState,
      scrollOffset: scrollOffset,
    );
    // Evict oldest entries if over capacity.
    while (updated.length > maxEntries) {
      updated.remove(updated.keys.first);
    }
    state = updated;
  }

  void saveScrollOffset(ConversationDetailTarget target, double scrollOffset) {
    if (!state.containsKey(target)) {
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
    final updated =
        Map<ConversationDetailTarget, ConversationDetailSessionEntry>.from(
            state);
    for (final entry in _pendingScrollOffsets.entries) {
      final existing = updated[entry.key];
      if (existing != null) {
        updated[entry.key] = existing.copyWith(scrollOffset: entry.value);
      }
    }
    _pendingScrollOffsets.clear();
    state = updated;
  }
}
