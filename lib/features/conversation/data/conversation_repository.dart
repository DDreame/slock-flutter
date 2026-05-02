import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

enum ConversationSurface { channel, directMessage }

@immutable
class ConversationDetailTarget {
  const ConversationDetailTarget._({
    required this.serverId,
    required this.conversationId,
    required this.surface,
  });

  factory ConversationDetailTarget.channel(ChannelScopeId scopeId) {
    return ConversationDetailTarget._(
      serverId: scopeId.serverId,
      conversationId: scopeId.value,
      surface: ConversationSurface.channel,
    );
  }

  factory ConversationDetailTarget.directMessage(
    DirectMessageScopeId scopeId,
  ) {
    return ConversationDetailTarget._(
      serverId: scopeId.serverId,
      conversationId: scopeId.value,
      surface: ConversationSurface.directMessage,
    );
  }

  final ServerScopeId serverId;
  final String conversationId;
  final ConversationSurface surface;

  String get defaultTitle => switch (surface) {
        ConversationSurface.channel => '#$conversationId',
        ConversationSurface.directMessage => 'Direct message',
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ConversationDetailTarget &&
            runtimeType == other.runtimeType &&
            serverId == other.serverId &&
            conversationId == other.conversationId &&
            surface == other.surface;
  }

  @override
  int get hashCode => Object.hash(serverId, conversationId, surface);
}

abstract class ConversationRepository {
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  );

  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  });

  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  });

  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment,
  );

  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
  });

  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  });

  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  });

  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  });

  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  });

  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  });

  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  });
}

@immutable
class ConversationDetailSnapshot {
  const ConversationDetailSnapshot({
    required this.target,
    required this.title,
    required this.messages,
    required this.historyLimited,
    required this.hasOlder,
    this.memberCount,
  });

  final ConversationDetailTarget target;
  final String title;
  final List<ConversationMessageSummary> messages;
  final bool historyLimited;
  final bool hasOlder;
  final int? memberCount;
}

@immutable
class ConversationMessagePage {
  const ConversationMessagePage({
    required this.messages,
    required this.historyLimited,
    required this.hasOlder,
    this.hasNewer = false,
  });

  final List<ConversationMessageSummary> messages;
  final bool historyLimited;
  final bool hasOlder;
  final bool hasNewer;
}

@immutable
class MessageAttachment {
  const MessageAttachment({
    required this.name,
    required this.type,
    this.url,
    this.id,
    this.sizeBytes,
  });

  final String name;
  final String type;
  final String? url;
  final String? id;
  final int? sizeBytes;

  /// Formats [sizeBytes] into a human-readable string (e.g. "2.4 MB").
  /// Returns `null` when [sizeBytes] is absent.
  String? get formattedSize {
    final bytes = sizeBytes;
    if (bytes == null) return null;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MessageAttachment &&
            runtimeType == other.runtimeType &&
            name == other.name &&
            type == other.type &&
            url == other.url &&
            id == other.id &&
            sizeBytes == other.sizeBytes;
  }

  @override
  int get hashCode => Object.hash(name, type, url, id, sizeBytes);
}

@immutable
class ConversationLinkedTaskSummary {
  const ConversationLinkedTaskSummary({
    required this.id,
    required this.taskNumber,
    required this.status,
    this.claimedByName,
  });

  final String id;
  final int taskNumber;
  final String status;
  final String? claimedByName;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ConversationLinkedTaskSummary &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            taskNumber == other.taskNumber &&
            status == other.status &&
            claimedByName == other.claimedByName;
  }

  @override
  int get hashCode => Object.hash(id, taskNumber, status, claimedByName);
}

@immutable
class ConversationMessageSummary {
  const ConversationMessageSummary({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.senderType,
    required this.messageType,
    this.senderId,
    this.senderName,
    this.seq,
    this.attachments,
    this.threadId,
    this.replyCount,
    this.linkedTaskId,
    this.linkedTask,
    this.isPinned = false,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final String senderType;
  final String messageType;
  final String? senderId;
  final String? senderName;
  final int? seq;
  final List<MessageAttachment>? attachments;
  final String? threadId;
  final int? replyCount;
  final String? linkedTaskId;
  final ConversationLinkedTaskSummary? linkedTask;
  final bool isPinned;

  bool get isSystem => messageType == 'system';

  String get senderLabel =>
      senderName ??
      switch (senderType) {
        'agent' => 'Agent',
        'human' || 'member' || 'user' => 'Member',
        _ => 'System',
      };

  ConversationMessageSummary copyWith({
    String? content,
    List<MessageAttachment>? attachments,
    String? threadId,
    int? replyCount,
    String? linkedTaskId,
    ConversationLinkedTaskSummary? linkedTask,
    bool? isPinned,
  }) {
    return ConversationMessageSummary(
      id: id,
      content: content ?? this.content,
      createdAt: createdAt,
      senderType: senderType,
      messageType: messageType,
      senderId: senderId,
      senderName: senderName,
      seq: seq,
      attachments: attachments ?? this.attachments,
      threadId: threadId ?? this.threadId,
      replyCount: replyCount ?? this.replyCount,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      linkedTask: linkedTask ?? this.linkedTask,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ConversationMessageSummary &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            content == other.content &&
            createdAt == other.createdAt &&
            senderType == other.senderType &&
            messageType == other.messageType &&
            senderId == other.senderId &&
            senderName == other.senderName &&
            seq == other.seq &&
            _listEquals(attachments, other.attachments) &&
            threadId == other.threadId &&
            replyCount == other.replyCount &&
            linkedTaskId == other.linkedTaskId &&
            linkedTask == other.linkedTask &&
            isPinned == other.isPinned;
  }

  @override
  int get hashCode => Object.hash(
        id,
        content,
        createdAt,
        senderType,
        messageType,
        senderId,
        senderName,
        seq,
        attachments == null ? null : Object.hashAll(attachments!),
        threadId,
        replyCount,
        linkedTaskId,
        linkedTask,
        isPinned,
      );

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
