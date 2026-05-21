import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';

/// The delivery status of a locally-originated message.
enum MessageSendStatus {
  /// Message is being sent to the server.
  sending,

  /// Message has been queued in the outbox for automatic retry.
  queued,

  /// Message was successfully delivered.
  sent,

  /// Message failed to send and can be retried.
  failed,
}

/// A message that has been optimistically inserted into the conversation
/// list before receiving server confirmation.
///
/// Tracks the local lifecycle: sending → sent | queued → sent | failed.
/// On success, replaced by the canonical [ConversationMessageSummary]
/// from the server response. On failure, retained with [status] == failed
/// so the user can tap to retry. On queued, the outbox will retry
/// automatically when connectivity is restored.
@immutable
class PendingMessage {
  const PendingMessage({
    required this.localId,
    required this.content,
    required this.createdAt,
    this.attachmentIds,
    this.replyToId,
    this.status = MessageSendStatus.sending,
    this.failure,
  });

  /// Client-generated unique identifier for deduplication.
  final String localId;

  /// The message body text.
  final String content;

  /// Attachment IDs already uploaded (ready to associate with message).
  final List<String>? attachmentIds;

  /// The ID of the message being replied to, if any.
  final String? replyToId;

  /// Current delivery status.
  final MessageSendStatus status;

  /// Timestamp when the user pressed send.
  final DateTime createdAt;

  /// Populated when [status] is [MessageSendStatus.failed].
  final AppFailure? failure;

  /// Create a copy with updated fields.
  PendingMessage copyWith({
    MessageSendStatus? status,
    List<String>? attachmentIds,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return PendingMessage(
      localId: localId,
      content: content,
      attachmentIds: attachmentIds ?? this.attachmentIds,
      replyToId: replyToId,
      createdAt: createdAt,
      status: status ?? this.status,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingMessage &&
          runtimeType == other.runtimeType &&
          localId == other.localId &&
          content == other.content &&
          listEquals(attachmentIds, other.attachmentIds) &&
          replyToId == other.replyToId &&
          status == other.status &&
          createdAt == other.createdAt &&
          _failureEquals(failure, other.failure);

  @override
  int get hashCode => Object.hash(
        localId,
        content,
        attachmentIds == null ? null : Object.hashAll(attachmentIds!),
        replyToId,
        status,
        createdAt,
        _failureHash(failure),
      );
}

bool _failureEquals(AppFailure? left, AppFailure? right) {
  if (identical(left, right)) return true;
  if (left == null || right == null) return false;
  return left.runtimeType == right.runtimeType &&
      left.message == right.message &&
      left.statusCode == right.statusCode &&
      left.requestId == right.requestId &&
      left.causeType == right.causeType;
}

Object? _failureHash(AppFailure? failure) {
  if (failure == null) return null;
  return Object.hash(
    failure.runtimeType,
    failure.message,
    failure.statusCode,
    failure.requestId,
    failure.causeType,
  );
}
