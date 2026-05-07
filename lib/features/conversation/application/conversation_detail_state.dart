import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

enum ConversationDetailStatus { initial, loading, success, failure }

@immutable
class ConversationDetailState {
  const ConversationDetailState({
    required this.target,
    this.status = ConversationDetailStatus.initial,
    this.title,
    this.memberCount,
    this.messages = const [],
    this.pendingMessages = const [],
    this.historyLimited = false,
    this.hasOlder = false,
    this.hasNewer = false,
    this.draft = '',
    this.pendingAttachments = const [],
    this.uploadProgress = const {},
    this.isSending = false,
    this.isLoadingOlder = false,
    this.isLoadingNewer = false,
    this.failure,
    this.sendFailure,
    this.isSearchActive = false,
    this.searchQuery = '',
    this.searchMatchIds = const [],
    this.currentSearchMatchIndex = -1,
    this.savedMessageIds = const {},
    this.replyToMessage,
  });

  final ConversationDetailTarget target;
  final ConversationDetailStatus status;
  final String? title;
  final int? memberCount;
  final List<ConversationMessageSummary> messages;

  /// Messages that have been optimistically inserted but not yet confirmed.
  final List<PendingMessage> pendingMessages;
  final bool historyLimited;
  final bool hasOlder;
  final bool hasNewer;
  final String draft;
  final List<PendingAttachment> pendingAttachments;

  /// Per-attachment upload progress. Key is attachment index, value is 0.0–1.0.
  /// Cleared after all uploads complete (success or cancel).
  final Map<int, double> uploadProgress;
  final bool isSending;
  final bool isLoadingOlder;
  final bool isLoadingNewer;
  final AppFailure? failure;
  final AppFailure? sendFailure;
  final bool isSearchActive;
  final String searchQuery;
  final List<String> searchMatchIds;
  final int currentSearchMatchIndex;
  final Set<String> savedMessageIds;

  /// When non-null, the composer shows a quote preview and the next send
  /// includes `replyToId` in the payload.
  final ConversationMessageSummary? replyToMessage;

  bool get isEmpty =>
      status == ConversationDetailStatus.success &&
      messages.isEmpty &&
      pendingMessages.isEmpty;

  String get resolvedTitle => title ?? target.defaultTitle;

  bool get canSend =>
      status == ConversationDetailStatus.success &&
      (draft.trim().isNotEmpty || pendingAttachments.isNotEmpty);

  ConversationDetailState copyWith({
    ConversationDetailTarget? target,
    ConversationDetailStatus? status,
    String? title,
    int? memberCount,
    List<ConversationMessageSummary>? messages,
    List<PendingMessage>? pendingMessages,
    bool? historyLimited,
    bool? hasOlder,
    bool? hasNewer,
    String? draft,
    List<PendingAttachment>? pendingAttachments,
    Map<int, double>? uploadProgress,
    bool? isSending,
    bool? isLoadingOlder,
    bool? isLoadingNewer,
    AppFailure? failure,
    AppFailure? sendFailure,
    bool clearFailure = false,
    bool clearSendFailure = false,
    bool? isSearchActive,
    String? searchQuery,
    List<String>? searchMatchIds,
    int? currentSearchMatchIndex,
    Set<String>? savedMessageIds,
    ConversationMessageSummary? replyToMessage,
    bool clearReplyToMessage = false,
  }) {
    return ConversationDetailState(
      target: target ?? this.target,
      status: status ?? this.status,
      title: title ?? this.title,
      memberCount: memberCount ?? this.memberCount,
      messages: messages ?? this.messages,
      pendingMessages: pendingMessages ?? this.pendingMessages,
      historyLimited: historyLimited ?? this.historyLimited,
      hasOlder: hasOlder ?? this.hasOlder,
      hasNewer: hasNewer ?? this.hasNewer,
      draft: draft ?? this.draft,
      pendingAttachments: pendingAttachments ?? this.pendingAttachments,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isSending: isSending ?? this.isSending,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isLoadingNewer: isLoadingNewer ?? this.isLoadingNewer,
      failure: clearFailure ? null : (failure ?? this.failure),
      sendFailure: clearSendFailure ? null : (sendFailure ?? this.sendFailure),
      isSearchActive: isSearchActive ?? this.isSearchActive,
      searchQuery: searchQuery ?? this.searchQuery,
      searchMatchIds: searchMatchIds ?? this.searchMatchIds,
      currentSearchMatchIndex:
          currentSearchMatchIndex ?? this.currentSearchMatchIndex,
      savedMessageIds: savedMessageIds ?? this.savedMessageIds,
      replyToMessage:
          clearReplyToMessage ? null : (replyToMessage ?? this.replyToMessage),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ConversationDetailState &&
            runtimeType == other.runtimeType &&
            target == other.target &&
            status == other.status &&
            title == other.title &&
            memberCount == other.memberCount &&
            listEquals(messages, other.messages) &&
            listEquals(pendingMessages, other.pendingMessages) &&
            historyLimited == other.historyLimited &&
            hasOlder == other.hasOlder &&
            hasNewer == other.hasNewer &&
            draft == other.draft &&
            listEquals(pendingAttachments, other.pendingAttachments) &&
            mapEquals(uploadProgress, other.uploadProgress) &&
            isSending == other.isSending &&
            isLoadingOlder == other.isLoadingOlder &&
            isLoadingNewer == other.isLoadingNewer &&
            failure == other.failure &&
            sendFailure == other.sendFailure &&
            isSearchActive == other.isSearchActive &&
            searchQuery == other.searchQuery &&
            listEquals(searchMatchIds, other.searchMatchIds) &&
            currentSearchMatchIndex == other.currentSearchMatchIndex &&
            setEquals(savedMessageIds, other.savedMessageIds) &&
            replyToMessage == other.replyToMessage;
  }

  @override
  int get hashCode => Object.hash(
        target,
        status,
        title,
        memberCount,
        Object.hashAll(messages),
        Object.hashAll(pendingMessages),
        historyLimited,
        hasOlder,
        hasNewer,
        draft,
        Object.hashAll(pendingAttachments),
        Object.hashAll(uploadProgress.entries),
        isSending,
        isLoadingOlder,
        isLoadingNewer,
        failure,
        sendFailure,
        Object.hash(
          isSearchActive,
          searchQuery,
          Object.hashAll(searchMatchIds),
          currentSearchMatchIndex,
          Object.hashAll(savedMessageIds),
          replyToMessage,
        ),
      );
}
