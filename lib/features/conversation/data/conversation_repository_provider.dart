import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

const _messagePageSize = 50;
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
        target: target,
      );
      return ConversationDetailSnapshot(
        target: target,
        title: _resolveTitle(
          responses[1].data,
          target: target,
        ),
        messages: messagesPayload.messages,
        historyLimited: messagesPayload.historyLimited,
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
  Object? payload, {
  required ConversationDetailTarget target,
}) {
  if (payload is List) {
    return _MessagesPayload(
      messages: _parseMessageList(
        payload,
        payloadName: 'messages',
      ),
      historyLimited: false,
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
  );
}

List<ConversationMessageSummary> _parseMessageList(
  List<Object?> payload, {
  required String payloadName,
}) {
  return List<ConversationMessageSummary>.generate(payload.length, (index) {
    final item = _requireMap(
      payload[index],
      payloadName: '$payloadName[$index]',
    );
    return ConversationMessageSummary(
      id: _requireStringField(
        item,
        field: 'id',
        payloadName: '$payloadName[$index]',
      ),
      content: _requireStringField(
        item,
        field: 'content',
        payloadName: '$payloadName[$index]',
      ),
      createdAt: _requireDateTimeField(
        item,
        field: 'createdAt',
        payloadName: '$payloadName[$index]',
      ),
      senderType: _readOptionalString(item['senderType']) ?? 'system',
      messageType: _readOptionalString(item['messageType']) ?? 'message',
      seq: _readOptionalInt(item['seq']),
    );
  }, growable: false);
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
        final title = _firstPresentString(
          item,
          fields: const ['displayName', 'name', 'title'],
        );
        if (title != null && title.isNotEmpty) {
          return title;
        }
    }
  }

  return target.defaultTitle;
}

List<Object?> _requireList(Object? payload, {required String payloadName}) {
  if (payload is List) {
    return List<Object?>.from(payload);
  }
  throw SerializationFailure(
    message: 'Malformed $payloadName payload: expected a list.',
    causeType: _describeType(payload),
  );
}

Map<String, dynamic> _requireMap(Object? payload,
    {required String payloadName}) {
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }
  throw SerializationFailure(
    message: 'Malformed $payloadName payload: expected an object.',
    causeType: _describeType(payload),
  );
}

String _requireStringField(
  Map<String, dynamic> payload, {
  required String field,
  required String payloadName,
}) {
  final value = _readOptionalString(payload[field]);
  if (value != null) {
    return value;
  }
  throw SerializationFailure(
    message: 'Malformed $payloadName payload: missing string field "$field".',
    causeType: _describeType(payload[field]),
  );
}

DateTime _requireDateTimeField(
  Map<String, dynamic> payload, {
  required String field,
  required String payloadName,
}) {
  final rawValue = _readOptionalString(payload[field]);
  final parsed = rawValue != null ? DateTime.tryParse(rawValue) : null;
  if (parsed != null) {
    return parsed;
  }
  throw SerializationFailure(
    message:
        'Malformed $payloadName payload: invalid ISO datetime field "$field".',
    causeType: _describeType(payload[field]),
  );
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

String? _firstPresentString(
  Map<String, dynamic> payload, {
  required List<String> fields,
}) {
  for (final field in fields) {
    final value = _readOptionalString(payload[field]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

String? _readOptionalString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

int? _readOptionalInt(Object? value) {
  if (value is int) {
    return value;
  }
  return null;
}

String _describeType(Object? value) => value?.runtimeType.toString() ?? 'Null';

class _MessagesPayload {
  const _MessagesPayload({
    required this.messages,
    required this.historyLimited,
  });

  final List<ConversationMessageSummary> messages;
  final bool historyLimited;
}
