import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_identity_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

const _messagePageSize = 50;
const _sendMessagePath = '/messages';
const _uploadPath = '/upload';
const _messagesPathPrefix = '/messages/channel/';
const _channelsPath = '/channels';
const _directMessageChannelsPath = '/channels/dm';
const _serverHeaderName = 'X-Server-Id';
const _channelSurface = 'channel';
const _directMessageSurface = 'direct_message';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final localStore = ref.watch(conversationLocalStoreProvider);
  return _ApiConversationRepository(
    appDioClient: appDioClient,
    localStore: localStore,
  );
});

class _ApiConversationRepository implements ConversationRepository {
  const _ApiConversationRepository({
    required AppDioClient appDioClient,
    required ConversationLocalStore localStore,
  })  : _appDioClient = appDioClient,
        _localStore = localStore;

  final AppDioClient _appDioClient;
  final ConversationLocalStore _localStore;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    try {
      final responses = await Future.wait([
        _appDioClient.get<Object?>(
          '$_messagesPathPrefix${target.conversationId}',
          queryParameters: const {'limit': _messagePageSize},
          options: _serverScopedOptions(target.serverId),
        ),
        _appDioClient.get<Object?>(
          _metadataPath(target.surface),
          options: _serverScopedOptions(target.serverId),
        ),
      ]);

      final messagesPayload = _parseMessagesPayload(
        responses[0].data,
        serverId: target.serverId.value,
        conversationId: target.conversationId,
      );
      final metadata = _resolveMetadata(
        responses[1].data,
        target: target,
      );

      await _localStore.upsertMessages(messagesPayload.storedMessages);
      await _localStore.upsertIdentities(messagesPayload.identities);
      await _localStore.upsertConversationSummaries(
        [
          LocalConversationSummaryUpsert(
            serverId: target.serverId.value,
            conversationId: target.conversationId,
            surface: _surfaceKey(target.surface),
            title: metadata.summaryTitle,
            sortIndex: 0,
            lastMessageId: messagesPayload.messages.isEmpty
                ? null
                : messagesPayload.messages.last.id,
            lastMessagePreview: messagesPayload.messages.isEmpty
                ? null
                : messagesPayload.messages.last.content,
            lastActivityAt: messagesPayload.messages.isEmpty
                ? null
                : messagesPayload.messages.last.createdAt,
          ),
        ],
        preserveExistingSortIndex: true,
      );

      final storedMessages = await _storedMessages(target);
      return ConversationDetailSnapshot(
        target: target,
        title: metadata.displayTitle,
        messages: storedMessages,
        historyLimited: messagesPayload.historyLimited,
        hasOlder: messagesPayload.hasOlder,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load conversation detail.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_messagesPathPrefix${target.conversationId}',
        queryParameters: {
          'limit': _messagePageSize,
          'before': beforeSeq,
        },
        options: _serverScopedOptions(target.serverId),
      );
      final payload = _parseMessagesPayload(
        response.data,
        serverId: target.serverId.value,
        conversationId: target.conversationId,
      );
      await _localStore.upsertMessages(payload.storedMessages);
      await _localStore.upsertIdentities(payload.identities);
      return ConversationMessagePage(
        messages: payload.messages,
        historyLimited: payload.historyLimited,
        hasOlder: payload.hasOlder,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load older conversation history.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_messagesPathPrefix${target.conversationId}',
        queryParameters: {
          'limit': _messagePageSize,
          'after': afterSeq,
        },
        options: _serverScopedOptions(target.serverId),
      );
      final payload = _parseMessagesPayload(
        response.data,
        serverId: target.serverId.value,
        conversationId: target.conversationId,
      );
      await _localStore.upsertMessages(payload.storedMessages);
      await _localStore.upsertIdentities(payload.identities);
      if (payload.messages.isNotEmpty) {
        final latest = payload.messages.last;
        await _localStore.touchConversationSummary(
          serverId: target.serverId.value,
          conversationId: target.conversationId,
          lastMessageId: latest.id,
          preview: latest.content,
          activityAt: latest.createdAt,
        );
      }
      return ConversationMessagePage(
        messages: payload.messages,
        historyLimited: payload.historyLimited,
        hasOlder: false,
        hasNewer: payload.messages.length >= _messagePageSize,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load newer conversation history.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          attachment.path,
          filename: attachment.name,
          contentType: DioMediaType.parse(attachment.mimeType),
        ),
      });
      final response = await _appDioClient.post<Object?>(
        _uploadPath,
        data: formData,
        options: _serverScopedOptions(target.serverId).copyWith(
          sendTimeout: const Duration(minutes: 2),
        ),
      );
      final map = requireConversationPayloadMap(
        response.data,
        payloadName: 'uploadResponse',
      );
      final id = readOptionalConversationPayloadString(map['id']);
      if (id == null || id.isEmpty) {
        throw const SerializationFailure(
          message: 'Upload response missing attachment id.',
          causeType: 'uploadResponse',
        );
      }
      return id;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to upload attachment.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
  }) async {
    try {
      final data = <String, dynamic>{
        'channelId': target.conversationId,
        'content': content.trim(),
      };
      if (attachmentIds != null && attachmentIds.isNotEmpty) {
        data['attachmentIds'] = attachmentIds;
      }
      final response = await _appDioClient.post<Object?>(
        _sendMessagePath,
        data: data,
        options: _serverScopedOptions(target.serverId),
      );
      final message = _parseSingleMessage(
        response.data,
        payloadName: 'sendMessageResponse',
      );
      final stored = _storedMessageUpsert(
        response.data,
        serverId: target.serverId.value,
        conversationId: target.conversationId,
        payloadName: 'sendMessageResponse',
      );
      await _localStore.upsertMessages([stored]);
      await _localStore.upsertIdentities(
        _extractIdentityUpserts(
          response.data,
          serverId: target.serverId.value,
          senderIdFallback: null,
        ),
      );
      await _localStore.touchConversationSummary(
        serverId: target.serverId.value,
        conversationId: target.conversationId,
        lastMessageId: message.id,
        preview: message.content,
        activityAt: message.createdAt,
      );
      return message;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to send message.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    await _localStore.upsertMessages([
      _messageToLocalUpsert(
        message,
        serverId: target.serverId.value,
        conversationId: target.conversationId,
        senderId: senderId,
      ),
    ]);
    await _localStore.upsertIdentities(
      _messageIdentityUpserts(
        message,
        serverId: target.serverId.value,
        senderId: senderId,
      ),
    );
    await _localStore.touchConversationSummary(
      serverId: target.serverId.value,
      conversationId: target.conversationId,
      lastMessageId: message.id,
      preview: message.content,
      activityAt: message.createdAt,
    );
    return message;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    final stored = await _localStore.updateMessageContent(
      serverId: target.serverId.value,
      conversationId: target.conversationId,
      messageId: messageId,
      content: content,
    );
    if (stored == null) {
      return null;
    }
    await _localStore.updateConversationPreview(
      serverId: target.serverId.value,
      conversationId: target.conversationId,
      messageId: messageId,
      preview: content,
    );
    return _storedRowToMessage(stored);
  }

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    try {
      await _appDioClient.delete<Object?>(
        '$_sendMessagePath/$messageId',
        options: _serverScopedOptions(target.serverId),
      );
      await _localStore.removeMessage(
        serverId: target.serverId.value,
        conversationId: target.conversationId,
        messageId: messageId,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to delete message.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_sendMessagePath/$messageId/pin',
        options: _serverScopedOptions(target.serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to pin message.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    try {
      await _appDioClient.delete<Object?>(
        '$_sendMessagePath/$messageId/pin',
        options: _serverScopedOptions(target.serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to unpin message.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    await _localStore.removeMessage(
      serverId: target.serverId.value,
      conversationId: target.conversationId,
      messageId: messageId,
    );
  }

  Future<List<ConversationMessageSummary>> _storedMessages(
    ConversationDetailTarget target,
  ) async {
    final rows = await _localStore.listMessages(
      target.serverId.value,
      target.conversationId,
    );
    final messages = rows.map(_storedRowToMessage).toList(growable: false);
    messages.sort((left, right) {
      final leftSeq = left.seq;
      final rightSeq = right.seq;
      if (leftSeq != null && rightSeq != null && leftSeq != rightSeq) {
        return leftSeq.compareTo(rightSeq);
      }
      if (leftSeq != null && rightSeq == null) {
        return -1;
      }
      if (leftSeq == null && rightSeq != null) {
        return 1;
      }
      final createdAtComparison = left.createdAt.compareTo(right.createdAt);
      if (createdAtComparison != 0) {
        return createdAtComparison;
      }
      return left.id.compareTo(right.id);
    });
    return messages;
  }
}

Options _serverScopedOptions(ServerScopeId serverId) {
  return Options(headers: {_serverHeaderName: serverId.routeParam});
}

String _metadataPath(ConversationSurface surface) {
  return switch (surface) {
    ConversationSurface.channel => _channelsPath,
    ConversationSurface.directMessage => _directMessageChannelsPath,
  };
}

String _surfaceKey(ConversationSurface surface) {
  return switch (surface) {
    ConversationSurface.channel => _channelSurface,
    ConversationSurface.directMessage => _directMessageSurface,
  };
}

_MessagesPayload _parseMessagesPayload(
  Object? payload, {
  required String serverId,
  required String conversationId,
}) {
  if (payload is List) {
    return _messagesPayloadFromList(
      payload,
      serverId: serverId,
      conversationId: conversationId,
      payloadName: 'messages',
      historyLimited: false,
    );
  }

  final map = _requireMap(payload, payloadName: 'messagesResponse');
  final messages = _requireList(
    map['messages'],
    payloadName: 'messagesResponse.messages',
  );
  return _messagesPayloadFromList(
    messages,
    serverId: serverId,
    conversationId: conversationId,
    payloadName: 'messagesResponse.messages',
    historyLimited: _readBool(
      map,
      field: 'historyLimited',
      payloadName: 'messagesResponse',
    ),
  );
}

_MessagesPayload _messagesPayloadFromList(
  List<Object?> payload, {
  required String serverId,
  required String conversationId,
  required String payloadName,
  required bool historyLimited,
}) {
  final messages = <ConversationMessageSummary>[];
  final storedMessages = <LocalMessageUpsert>[];
  final identities = <LocalIdentityUpsert>[];

  for (var index = 0; index < payload.length; index++) {
    final itemPayload = payload[index];
    final itemName = '$payloadName[$index]';
    messages.add(_parseSingleMessage(itemPayload, payloadName: itemName));
    storedMessages.add(_storedMessageUpsert(
      itemPayload,
      serverId: serverId,
      conversationId: conversationId,
      payloadName: itemName,
    ));
    identities.addAll(_extractIdentityUpserts(
      itemPayload,
      serverId: serverId,
      senderIdFallback: null,
    ));
  }

  return _MessagesPayload(
    messages: messages,
    historyLimited: historyLimited,
    hasOlder: payload.length >= _messagePageSize,
    storedMessages: storedMessages,
    identities: _dedupeIdentityUpserts(identities),
  );
}

ConversationMessageSummary _parseSingleMessage(
  Object? payload, {
  required String payloadName,
}) {
  return parseConversationMessageSummary(payload, payloadName: payloadName);
}

_ConversationMetadata _resolveMetadata(
  Object? payload, {
  required ConversationDetailTarget target,
}) {
  final items = _requireList(payload, payloadName: 'conversationMetadata');
  for (var index = 0; index < items.length; index++) {
    final item = _requireMap(
      items[index],
      payloadName: 'conversationMetadata[$index]',
    );
    if (_readOptionalString(item['id']) != target.conversationId) {
      continue;
    }

    switch (target.surface) {
      case ConversationSurface.channel:
        final name = _readOptionalString(item['name']);
        if (name != null && name.isNotEmpty) {
          return _ConversationMetadata(
            displayTitle: '#$name',
            summaryTitle: name,
          );
        }
      case ConversationSurface.directMessage:
        final title = resolveDirectMessageTitle(item);
        if (title != null && title.isNotEmpty) {
          return _ConversationMetadata(
            displayTitle: title,
            summaryTitle: title,
          );
        }
    }
  }

  return _ConversationMetadata(
    displayTitle: target.defaultTitle,
    summaryTitle: switch (target.surface) {
      ConversationSurface.channel => target.defaultTitle.replaceFirst('#', ''),
      ConversationSurface.directMessage => target.defaultTitle,
    },
  );
}

LocalMessageUpsert _storedMessageUpsert(
  Object? payload, {
  required String serverId,
  required String conversationId,
  required String payloadName,
}) {
  final item = _requireMap(payload, payloadName: payloadName);
  final message = _parseSingleMessage(payload, payloadName: payloadName);
  return _messageToLocalUpsert(
    message,
    serverId: serverId,
    conversationId: conversationId,
    senderId: _readOptionalString(item['senderId']),
  );
}

LocalMessageUpsert _messageToLocalUpsert(
  ConversationMessageSummary message, {
  required String serverId,
  required String conversationId,
  required String? senderId,
}) {
  return LocalMessageUpsert(
    serverId: serverId,
    conversationId: conversationId,
    messageId: message.id,
    content: message.content,
    createdAt: message.createdAt,
    senderType: message.senderType,
    messageType: message.messageType,
    senderId: senderId,
    senderName: message.senderName,
    seq: message.seq,
    attachmentsJson: LocalMessageUpsert.encodeAttachments(
      message.attachments
          ?.map((attachment) => {
                'name': attachment.name,
                'type': attachment.type,
                'url': attachment.url,
                'id': attachment.id,
              })
          .toList(growable: false),
    ),
    threadId: message.threadId,
  );
}

List<LocalIdentityUpsert> _extractIdentityUpserts(
  Object? payload, {
  required String serverId,
  required String? senderIdFallback,
}) {
  final item = _requireMap(payload, payloadName: 'identityPayload');
  final results = <LocalIdentityUpsert>[];

  final senderId = _readOptionalString(item['senderId']) ?? senderIdFallback;
  final senderName = resolveConversationSenderName(item);
  if (senderId != null && senderName != null) {
    results.add(LocalIdentityUpsert(
      serverId: serverId,
      identityId: senderId,
      displayName: senderName,
      avatarUrl: _readOptionalAvatarUrl(item),
    ));
  }

  for (final field in const [
    'sender',
    'user',
    'member',
    'participant',
    'peer'
  ]) {
    final nested = item[field];
    if (nested is! Map) {
      continue;
    }
    final map = nested is Map<String, dynamic>
        ? nested
        : Map<String, dynamic>.from(nested);
    final identityId = _readOptionalString(map['id']);
    final displayName = _readOptionalString(map['displayName']) ??
        _readOptionalString(map['name']) ??
        _readOptionalString(map['title']) ??
        _readOptionalString(map['senderName']);
    if (identityId == null || displayName == null) {
      continue;
    }
    results.add(LocalIdentityUpsert(
      serverId: serverId,
      identityId: identityId,
      displayName: displayName,
      avatarUrl: _readOptionalAvatarUrl(map),
    ));
  }

  return _dedupeIdentityUpserts(results);
}

List<LocalIdentityUpsert> _messageIdentityUpserts(
  ConversationMessageSummary message, {
  required String serverId,
  required String? senderId,
}) {
  if (senderId == null || message.senderName == null) {
    return const [];
  }
  return [
    LocalIdentityUpsert(
      serverId: serverId,
      identityId: senderId,
      displayName: message.senderName!,
    ),
  ];
}

List<LocalIdentityUpsert> _dedupeIdentityUpserts(
  List<LocalIdentityUpsert> identities,
) {
  final deduped = <String, LocalIdentityUpsert>{};
  for (final identity in identities) {
    deduped['${identity.serverId}:${identity.identityId}'] = identity;
  }
  return deduped.values.toList(growable: false);
}

ConversationMessageSummary _storedRowToMessage(LocalStoredMessageRecord row) {
  return ConversationMessageSummary(
    id: row.messageId,
    content: row.content,
    createdAt: row.createdAt,
    senderType: row.senderType,
    messageType: row.messageType,
    senderName: row.senderName,
    seq: row.seq,
    attachments: _decodeAttachments(row.attachmentsJson),
    threadId: row.threadId,
  );
}

List<MessageAttachment>? _decodeAttachments(String? payload) {
  if (payload == null || payload.isEmpty) {
    return null;
  }
  final decoded = jsonDecode(payload);
  if (decoded is! List) {
    return null;
  }
  final attachments = <MessageAttachment>[];
  for (final item in decoded) {
    if (item is! Map) {
      continue;
    }
    final map =
        item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
    final name = _readOptionalString(map['name']);
    final type = _readOptionalString(map['type']);
    if (name == null || type == null) {
      continue;
    }
    attachments.add(MessageAttachment(
      name: name,
      type: type,
      url: _readOptionalString(map['url']),
      id: _readOptionalString(map['id']),
    ));
  }
  return attachments.isEmpty ? null : attachments;
}

List<Object?> _requireList(Object? payload, {required String payloadName}) {
  return requireConversationPayloadList(payload, payloadName: payloadName);
}

Map<String, dynamic> _requireMap(Object? payload,
    {required String payloadName}) {
  return requireConversationPayloadMap(payload, payloadName: payloadName);
}

bool _readBool(
  Map<String, dynamic> payload, {
  required String field,
  required String payloadName,
}) {
  final value = payload[field];
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  throw SerializationFailure(
    message: 'Malformed $payloadName payload: invalid bool field "$field".',
    causeType: _describeType(value),
  );
}

String? _readOptionalString(Object? value) {
  return readOptionalConversationPayloadString(value);
}

String? _readOptionalAvatarUrl(Map<String, dynamic> payload) {
  return _readOptionalString(payload['avatarUrl']) ??
      _readOptionalString(payload['avatar']);
}

String _describeType(Object? value) => describeConversationPayloadType(value);

class _ConversationMetadata {
  const _ConversationMetadata({
    required this.displayTitle,
    required this.summaryTitle,
  });

  final String displayTitle;
  final String summaryTitle;
}

class _MessagesPayload {
  const _MessagesPayload({
    required this.messages,
    required this.historyLimited,
    required this.hasOlder,
    required this.storedMessages,
    required this.identities,
  });

  final List<ConversationMessageSummary> messages;
  final bool historyLimited;
  final bool hasOlder;
  final List<LocalMessageUpsert> storedMessages;
  final List<LocalIdentityUpsert> identities;
}
