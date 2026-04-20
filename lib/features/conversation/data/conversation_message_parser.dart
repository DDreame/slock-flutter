import 'package:slock_app/core/core.dart';
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
  return ConversationMessageSummary(
    id: requireConversationPayloadStringField(
      item,
      field: 'id',
      payloadName: payloadName,
    ),
    content: requireConversationPayloadStringField(
      item,
      field: 'content',
      payloadName: payloadName,
    ),
    createdAt: requireConversationPayloadDateTimeField(
      item,
      field: 'createdAt',
      payloadName: payloadName,
    ),
    senderType:
        readOptionalConversationPayloadString(item['senderType']) ?? 'system',
    messageType:
        readOptionalConversationPayloadString(item['messageType']) ?? 'message',
    seq: readOptionalConversationPayloadInt(item['seq']),
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

String describeConversationPayloadType(Object? value) {
  return value?.runtimeType.toString() ?? 'Null';
}
