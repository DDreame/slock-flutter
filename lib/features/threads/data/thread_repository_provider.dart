import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';

const _serverHeaderName = 'X-Server-Id';
const _followedThreadsPath = '/channels/threads/followed';
const _followThreadPath = '/channels/threads/follow';
const _doneThreadPath = '/channels/threads/done';
const _threadsPathSuffix = '/threads';
const _readAllSuffix = '/read-all';

final threadRepositoryProvider = Provider<ThreadRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiThreadRepository(appDioClient: appDioClient);
});

class _ApiThreadRepository implements ThreadRepository {
  const _ApiThreadRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
      ServerScopeId serverId) async {
    try {
      final response = await _appDioClient.get<Object?>(
        _followedThreadsPath,
        options: _serverScopedOptions(serverId),
      );
      return _parseFollowedThreads(
        response.data,
        serverId: serverId,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load followed threads.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) async {
    try {
      final response = await _appDioClient.post<Object?>(
        '/channels/${target.parentChannelId}$_threadsPathSuffix',
        data: {'parentMessageId': target.parentMessageId},
        options: _serverScopedOptions(ServerScopeId(target.serverId)),
      );
      return _parseResolvedThread(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to open thread replies.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> followThread(ThreadRouteTarget target) async {
    try {
      await _appDioClient.post<Object?>(
        _followThreadPath,
        data: {'parentMessageId': target.parentMessageId},
        options: _serverScopedOptions(ServerScopeId(target.serverId)),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to follow thread.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        _doneThreadPath,
        data: {'threadChannelId': threadChannelId},
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to mark thread done.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '/channels/$threadChannelId$_readAllSuffix',
        options: _serverScopedOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to mark thread read.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  Options _serverScopedOptions(ServerScopeId serverId) {
    return Options(headers: {_serverHeaderName: serverId.value});
  }
}

List<ThreadInboxItem> _parseFollowedThreads(
  Object? payload, {
  required ServerScopeId serverId,
}) {
  final list = switch (payload) {
    List() => requireConversationPayloadList(
        payload,
        payloadName: 'followedThreadsResponse',
      ),
    _ => requireConversationPayloadList(
        requireConversationPayloadMap(
          payload,
          payloadName: 'followedThreadsResponse',
        )['threads'],
        payloadName: 'followedThreadsResponse.threads',
      ),
  };

  return [
    for (var i = 0; i < list.length; i++)
      _parseThreadInboxItem(
        list[i],
        payloadName: 'followedThreadsResponse.threads[$i]',
        serverId: serverId,
      ),
  ];
}

ThreadInboxItem _parseThreadInboxItem(
  Object? payload, {
  required String payloadName,
  required ServerScopeId serverId,
}) {
  final map = requireConversationPayloadMap(payload, payloadName: payloadName);
  final parentChannelId = _firstString(
    map,
    fields: const ['channelId', 'parentChannelId'],
  );
  final parentMessageId = _firstString(
    map,
    fields: const ['parentMessageId', 'messageId'],
  );
  if (parentChannelId == null || parentMessageId == null) {
    throw SerializationFailure(
      message:
          'Malformed $payloadName payload: missing thread route context fields.',
      causeType: describeConversationPayloadType(payload),
    );
  }

  return ThreadInboxItem(
    routeTarget: ThreadRouteTarget(
      serverId: serverId.value,
      parentChannelId: parentChannelId,
      parentMessageId: parentMessageId,
      threadChannelId: _firstString(
        map,
        fields: const ['threadChannelId'],
      ),
      isFollowed: true,
    ),
    title: _firstString(
      map,
      fields: const [
        'channelName',
        'parentChannelName',
        'conversationName',
        'conversationTitle',
      ],
    ),
    preview: _firstString(
      map,
      fields: const ['parentMessagePreview', 'preview', 'content'],
    ),
    senderName: _firstString(
      map,
      fields: const ['parentMessageSenderName', 'senderName'],
    ),
    replyCount: readOptionalConversationPayloadInt(map['replyCount']) ?? 0,
    unreadCount: readOptionalConversationPayloadInt(map['unreadCount']) ?? 0,
    lastReplyAt: _readOptionalDateTime(map['lastReplyAt']),
    participantIds: _readOptionalStringList(map['participantIds']),
  );
}

ResolvedThreadChannel _parseResolvedThread(Object? payload) {
  final map = requireConversationPayloadMap(
    payload,
    payloadName: 'resolveThreadResponse',
  );
  final threadChannelId = _firstString(
    map,
    fields: const ['threadChannelId', 'channelId'],
  );
  if (threadChannelId == null) {
    throw SerializationFailure(
      message:
          'Malformed resolveThreadResponse payload: missing string field "threadChannelId".',
      causeType: describeConversationPayloadType(payload),
    );
  }

  return ResolvedThreadChannel(
    threadChannelId: threadChannelId,
    replyCount: readOptionalConversationPayloadInt(map['replyCount']) ?? 0,
    participantIds: _readOptionalStringList(map['participantIds']),
    lastReplyAt: _readOptionalDateTime(map['lastReplyAt']),
  );
}

String? _firstString(
  Map<String, dynamic> map, {
  required List<String> fields,
}) {
  for (final field in fields) {
    final value = readOptionalConversationPayloadString(map[field]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

DateTime? _readOptionalDateTime(Object? value) {
  final raw = readOptionalConversationPayloadString(value);
  return raw == null ? null : DateTime.tryParse(raw);
}

List<String> _readOptionalStringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map(readOptionalConversationPayloadString)
      .whereType<String>()
      .toList(growable: false);
}
