import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_identity_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

class ConversationIncomingMessage {
  const ConversationIncomingMessage({
    required this.conversationId,
    required this.message,
    this.senderId,
  });

  final String conversationId;
  final ConversationMessageSummary message;
  final String? senderId;
}

ConversationIncomingMessage? tryParseConversationIncomingMessage(
  Object? payload, {
  required String payloadName,
}) {
  try {
    return parseConversationIncomingMessage(payload, payloadName: payloadName);
  } on AppFailure {
    return null;
  }
}

ConversationIncomingMessage parseConversationIncomingMessage(
  Object? payload, {
  required String payloadName,
}) {
  final item = requireConversationPayloadMap(payload, payloadName: payloadName);
  return ConversationIncomingMessage(
    conversationId: requireConversationPayloadStringField(
      item,
      field: 'channelId',
      payloadName: payloadName,
    ),
    message: parseConversationMessageSummary(payload, payloadName: payloadName),
    senderId: readOptionalConversationPayloadString(item['senderId']),
  );
}

ConversationMessageSummary parseConversationMessageSummary(
  Object? payload, {
  required String payloadName,
}) {
  final item = requireConversationPayloadMap(payload, payloadName: payloadName);
  final linkedTask = _parseLinkedTask(item['linkedTask']);
  return ConversationMessageSummary(
    id: requireConversationPayloadStringField(
      item,
      field: 'id',
      payloadName: payloadName,
    ),
    content: readOptionalConversationPayloadString(item['content']) ?? '',
    createdAt: requireConversationPayloadDateTimeField(
      item,
      field: 'createdAt',
      payloadName: payloadName,
    ),
    senderType:
        readOptionalConversationPayloadString(item['senderType']) ?? 'system',
    messageType:
        readOptionalConversationPayloadString(item['messageType']) ?? 'message',
    senderId: readOptionalConversationPayloadString(item['senderId']),
    senderName: resolveConversationSenderName(item),
    seq: readOptionalConversationPayloadInt(item['seq']),
    attachments: parseAttachments(item['attachments']),
    threadId: readOptionalConversationPayloadString(item['threadId']),
    replyCount: readOptionalConversationPayloadInt(item['replyCount']),
    linkedTaskId: readOptionalConversationPayloadString(item['linkedTaskId']) ??
        linkedTask?.id,
    linkedTask: linkedTask,
    isPinned: item['isPinned'] == true,
    isDeleted: item['isDeleted'] == true ||
        readOptionalConversationPayloadString(item['deletedAt']) != null,
    reactions: parseReactions(item['reactions']),
    replyTo: _parseReplyTo(item['replyTo']),
  );
}

List<Object?> requireConversationPayloadList(
  Object? payload, {
  required String payloadName,
}) {
  if (payload is List) {
    return List<Object?>.from(payload);
  }
  throw SerializationFailure(
    message: 'Malformed $payloadName payload: expected a list.',
    causeType: describeConversationPayloadType(payload),
  );
}

Map<String, dynamic> requireConversationPayloadMap(
  Object? payload, {
  required String payloadName,
}) {
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }
  throw SerializationFailure(
    message: 'Malformed $payloadName payload: expected an object.',
    causeType: describeConversationPayloadType(payload),
  );
}

String requireConversationPayloadStringField(
  Map<String, dynamic> payload, {
  required String field,
  required String payloadName,
}) {
  final value = readOptionalConversationPayloadString(payload[field]);
  if (value != null) {
    return value;
  }
  throw SerializationFailure(
    message: 'Malformed $payloadName payload: missing string field "$field".',
    causeType: describeConversationPayloadType(payload[field]),
  );
}

DateTime requireConversationPayloadDateTimeField(
  Map<String, dynamic> payload, {
  required String field,
  required String payloadName,
}) {
  final rawValue = readOptionalConversationPayloadString(payload[field]);
  final parsed = rawValue != null ? DateTime.tryParse(rawValue) : null;
  if (parsed != null) {
    return parsed;
  }
  throw SerializationFailure(
    message:
        'Malformed $payloadName payload: invalid ISO datetime field "$field".',
    causeType: describeConversationPayloadType(payload[field]),
  );
}

String? readOptionalConversationPayloadString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

int? readOptionalConversationPayloadInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

/// Safely parses a DateTime from an optional ISO 8601 string value.
/// Returns null when the value is absent, empty, or malformed.
DateTime? _tryParseDateTime(Object? value) {
  final raw = readOptionalConversationPayloadString(value);
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

class MessageUpdatedPayload {
  const MessageUpdatedPayload({
    required this.id,
    required this.channelId,
    required this.content,
  });

  final String id;
  final String channelId;
  final String content;
}

MessageUpdatedPayload? tryParseMessageUpdatedPayload(Object? payload) {
  if (payload is! Map) {
    return null;
  }
  final map = payload is Map<String, dynamic>
      ? payload
      : Map<String, dynamic>.from(payload);
  final id = readOptionalConversationPayloadString(map['id']);
  final channelId = readOptionalConversationPayloadString(map['channelId']);
  if (id == null || channelId == null) {
    return null;
  }
  // Content must be present in the payload (key exists) but may be an empty
  // string — editing a message to empty is a valid operation. Distinguish
  // "field absent" (null / key not in JSON) from "field is empty string".
  if (!map.containsKey('content')) {
    return null;
  }
  final rawContent = map['content'];
  if (rawContent is! String) {
    return null;
  }
  return MessageUpdatedPayload(
      id: id, channelId: channelId, content: rawContent);
}

class MessageDeletedPayload {
  const MessageDeletedPayload({
    required this.id,
    required this.channelId,
  });

  final String id;
  final String channelId;
}

MessageDeletedPayload? tryParseMessageDeletedPayload(Object? payload) {
  if (payload is! Map) {
    return null;
  }
  final map = payload is Map<String, dynamic>
      ? payload
      : Map<String, dynamic>.from(payload);
  final id = readOptionalConversationPayloadString(map['id']) ??
      readOptionalConversationPayloadString(map['messageId']);
  final channelId = readOptionalConversationPayloadString(map['channelId']);
  if (id == null || channelId == null) {
    return null;
  }
  return MessageDeletedPayload(id: id, channelId: channelId);
}

class MessagePinnedPayload {
  const MessagePinnedPayload({
    required this.id,
    required this.channelId,
    required this.isPinned,
  });

  final String id;
  final String channelId;
  final bool isPinned;
}

MessagePinnedPayload? tryParseMessagePinnedPayload(
  Object? payload, {
  required bool isPinned,
}) {
  if (payload is! Map) {
    return null;
  }
  final map = payload is Map<String, dynamic>
      ? payload
      : Map<String, dynamic>.from(payload);
  final id = readOptionalConversationPayloadString(map['id']) ??
      readOptionalConversationPayloadString(map['messageId']);
  final channelId = readOptionalConversationPayloadString(map['channelId']);
  if (id == null || channelId == null) {
    return null;
  }
  return MessagePinnedPayload(
    id: id,
    channelId: channelId,
    isPinned: isPinned,
  );
}

String describeConversationPayloadType(Object? value) {
  return value?.runtimeType.toString() ?? 'Null';
}

/// Parses attachment list from API/realtime JSON payload.
///
/// Supports both old-style payload (`name`/`type`/`url`) and new-style
/// payload (`filename`/`mimeType`/`thumbnailUrl`). Old fields take
/// priority when both are present.
List<MessageAttachment>? parseAttachments(Object? value) {
  if (value is! List || value.isEmpty) {
    return null;
  }
  final results = <MessageAttachment>[];
  for (final item in value) {
    if (item is! Map) continue;
    final map =
        item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
    // Normalize: old fields (name/type/url) take precedence; fall back to
    // new fields (filename/mimeType/thumbnailUrl).
    final name = readOptionalConversationPayloadString(map['name']) ??
        readOptionalConversationPayloadString(map['filename']);
    final type = readOptionalConversationPayloadString(map['type']) ??
        readOptionalConversationPayloadString(map['mimeType']);
    if (name == null || type == null) continue;
    final thumbnailUrl =
        readOptionalConversationPayloadString(map['thumbnailUrl']);
    results.add(MessageAttachment(
      name: name,
      type: type,
      url: readOptionalConversationPayloadString(map['url']) ?? thumbnailUrl,
      id: readOptionalConversationPayloadString(map['id']),
      sizeBytes: readOptionalConversationPayloadInt(map['sizeBytes']),
      thumbnailUrl: thumbnailUrl,
      createdAt: _tryParseDateTime(map['createdAt']),
    ));
  }
  return results.isEmpty ? null : results;
}

ConversationLinkedTaskSummary? _parseLinkedTask(Object? value) {
  if (value is! Map) {
    return null;
  }
  final map =
      value is Map<String, dynamic> ? value : Map<String, dynamic>.from(value);
  final id = readOptionalConversationPayloadString(map['id']);
  final taskNumber = readOptionalConversationPayloadInt(map['taskNumber']);
  final status = readOptionalConversationPayloadString(map['status']);
  if (id == null || taskNumber == null || status == null) {
    return null;
  }
  return ConversationLinkedTaskSummary(
    id: id,
    taskNumber: taskNumber,
    status: status,
    claimedByName: readOptionalConversationPayloadString(map['claimedByName']),
  );
}

ReplyToSummary? _parseReplyTo(Object? value) {
  if (value is! Map) {
    return null;
  }
  final map =
      value is Map<String, dynamic> ? value : Map<String, dynamic>.from(value);
  final id = readOptionalConversationPayloadString(map['id']);
  if (id == null) {
    return null;
  }
  return ReplyToSummary(
    id: id,
    content: readOptionalConversationPayloadString(map['content']) ?? '',
    senderName: readOptionalConversationPayloadString(map['senderName']) ??
        resolveConversationSenderName(map),
    senderType: readOptionalConversationPayloadString(map['senderType']),
  );
}

/// Parses a list of reaction aggregates from the API payload.
///
/// Expected format: `[{"emoji": "👍", "count": 3, "userIds": ["u1", "u2", "u3"]}]`
List<MessageReaction> parseReactions(Object? value) {
  if (value is! List || value.isEmpty) {
    return const [];
  }
  final results = <MessageReaction>[];
  for (final item in value) {
    if (item is! Map) continue;
    final map =
        item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
    final emoji = readOptionalConversationPayloadString(map['emoji']);
    if (emoji == null) continue;
    final count = readOptionalConversationPayloadInt(map['count']) ?? 1;
    final rawUserIds = map['userIds'];
    final userIds = <String>[];
    if (rawUserIds is List) {
      for (final uid in rawUserIds) {
        final parsed = readOptionalConversationPayloadString(uid);
        if (parsed != null) {
          userIds.add(parsed);
        }
      }
    }
    results.add(MessageReaction(
      emoji: emoji,
      count: count,
      userIds: userIds,
    ));
  }
  return results;
}

class MessageReactionEventPayload {
  const MessageReactionEventPayload({
    required this.messageId,
    required this.channelId,
    required this.emoji,
    required this.userId,
  });

  final String messageId;
  final String channelId;
  final String emoji;
  final String userId;
}

MessageReactionEventPayload? tryParseReactionEventPayload(Object? payload) {
  if (payload is! Map) {
    return null;
  }
  final map = payload is Map<String, dynamic>
      ? payload
      : Map<String, dynamic>.from(payload);
  final messageId = readOptionalConversationPayloadString(map['messageId']);
  final channelId = readOptionalConversationPayloadString(map['channelId']);
  final emoji = readOptionalConversationPayloadString(map['emoji']);
  final userId = readOptionalConversationPayloadString(map['userId']);
  if (messageId == null ||
      channelId == null ||
      emoji == null ||
      userId == null) {
    return null;
  }
  return MessageReactionEventPayload(
    messageId: messageId,
    channelId: channelId,
    emoji: emoji,
    userId: userId,
  );
}
