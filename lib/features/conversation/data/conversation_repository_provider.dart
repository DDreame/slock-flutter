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

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiConversationRepository(appDioClient: appDioClient);
});

class _ApiConversationRepository implements ConversationRepository {
  const _ApiConversationRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    try {
      // Endpoint/header contract is inferred from the shipped web client.
      // Flutter still keeps scope explicit from the route/server param instead
      // of reading hidden global current-server state.
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
      );
      return ConversationDetailSnapshot(
        target: target,
        title: _resolveTitle(
          responses[1].data,
          target: target,
        ),
        messages: messagesPayload.messages,
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
      final payload = _parseMessagesPayload(response.data);
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
      final payload = _parseMessagesPayload(response.data);
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
      return _parseSingleMessage(
        response.data,
        payloadName: 'sendMessageResponse',
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to send message.',
        causeType: error.runtimeType.toString(),
      );
    }
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

_MessagesPayload _parseMessagesPayload(
  Object? payload,
) {
  if (payload is List) {
    return _MessagesPayload(
      messages: _parseMessageList(
        payload,
        payloadName: 'messages',
      ),
      historyLimited: false,
      hasOlder: payload.length >= _messagePageSize,
    );
  }

  final map = _requireMap(payload, payloadName: 'messagesResponse');
  return _MessagesPayload(
    messages: _parseMessageList(
      _requireList(
        map['messages'],
        payloadName: 'messagesResponse.messages',
      ),
      payloadName: 'messagesResponse.messages',
    ),
    historyLimited: _readBool(
      map,
      field: 'historyLimited',
      payloadName: 'messagesResponse',
    ),
    hasOlder: _requireList(
          map['messages'],
          payloadName: 'messagesResponse.messages',
        ).length >=
        _messagePageSize,
  );
}

List<ConversationMessageSummary> _parseMessageList(
  List<Object?> payload, {
  required String payloadName,
}) {
  return List<ConversationMessageSummary>.generate(payload.length, (index) {
    return _parseSingleMessage(
      payload[index],
      payloadName: '$payloadName[$index]',
    );
  }, growable: false);
}

ConversationMessageSummary _parseSingleMessage(
  Object? payload, {
  required String payloadName,
}) {
  return parseConversationMessageSummary(payload, payloadName: payloadName);
}

String _resolveTitle(
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
          return '#$name';
        }
      case ConversationSurface.directMessage:
        final title = resolveDirectMessageTitle(item);
        if (title != null && title.isNotEmpty) {
          return title;
        }
    }
  }

  return target.defaultTitle;
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

String _describeType(Object? value) => describeConversationPayloadType(value);

class _MessagesPayload {
  const _MessagesPayload({
    required this.messages,
    required this.historyLimited,
    required this.hasOlder,
  });

  final List<ConversationMessageSummary> messages;
  final bool historyLimited;
  final bool hasOlder;
}
