import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';

/// The delivery status of a locally-originated message.
enum MessageSendStatus {
  /// Message is being sent to the server.
  sending,

  /// Message was successfully delivered.
  sent,

  /// Message failed to send and can be retried.
  failed,
}

/// A message that has been optimistically inserted into the conversation
/// list before receiving server confirmation.
///
/// Tracks the local lifecycle: sending → sent | failed.
/// On success, replaced by the canonical [ConversationMessageSummary]
/// from the server response. On failure, retained with [status] == failed
/// so the user can tap to retry.
@immutable
class PendingMessage {
  const PendingMessage({
    required this.localId,
    required this.content,
    required this.createdAt,
    this.attachmentIds,
    this.status = MessageSendStatus.sending,
    this.failure,
  });

  /// Client-generated unique identifier for deduplication.
  final String localId;

  /// The message body text.
  final String content;

  /// Attachment IDs already uploaded (ready to associate with message).
  final List<String>? attachmentIds;

  /// Current delivery status.
  final MessageSendStatus status;

  /// Timestamp when the user pressed send.
  final DateTime createdAt;

  /// Populated when [status] is [MessageSendStatus.failed].
  final AppFailure? failure;

  /// Create a copy with updated fields.
  PendingMessage copyWith({
    MessageSendStatus? status,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return PendingMessage(
      localId: localId,
      content: content,
      attachmentIds: attachmentIds,
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
          status == other.status &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(localId, content, status, createdAt);
}
