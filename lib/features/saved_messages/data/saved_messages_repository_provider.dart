import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';

const _savedPath = '/channels/saved';
const _serverHeaderName = 'X-Server-Id';

final savedMessagesRepositoryProvider =
    Provider<SavedMessagesRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiSavedMessagesRepository(appDioClient: appDioClient);
});

class _ApiSavedMessagesRepository implements SavedMessagesRepository {
  const _ApiSavedMessagesRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  Options _serverOptions(ServerScopeId serverId) =>
      Options(headers: {_serverHeaderName: serverId.routeParam});

  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        _savedPath,
        queryParameters: {'limit': limit, 'offset': offset},
        options: _serverOptions(serverId),
      );
      return _parseListResponse(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load saved messages.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> saveMessage(
    ServerScopeId serverId,
    String messageId,
  ) async {
    try {
      await _appDioClient.post<Object?>(
        _savedPath,
        data: {'messageId': messageId},
        options: _serverOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to save message.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> unsaveMessage(
    ServerScopeId serverId,
    String messageId,
  ) async {
    try {
      await _appDioClient.delete<Object?>(
        '$_savedPath/$messageId',
        options: _serverOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to unsave message.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return {};
    try {
      final response = await _appDioClient.post<Object?>(
        '$_savedPath/check',
        data: {'messageIds': messageIds},
        options: _serverOptions(serverId),
      );
      return _parseCheckResponse(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to check saved messages.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  SavedMessagesPage _parseListResponse(Object? payload) {
    final map = requireConversationPayloadMap(
      payload,
      payloadName: 'savedMessagesResponse',
    );
    final results = map['results'];
    final hasMore = map['hasMore'] == true;

    if (results is! List) {
      return const SavedMessagesPage(items: [], hasMore: false);
    }

    final items = <SavedMessageItem>[];
    for (var i = 0; i < results.length; i++) {
      final item = results[i];
      if (item is! Map) continue;
      final itemMap =
          item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
      final message = parseConversationMessageSummary(
        itemMap,
        payloadName: 'savedMessagesResponse.results[$i]',
      );
      items.add(SavedMessageItem(
        message: message,
        channelId: requireConversationPayloadStringField(
          itemMap,
          field: 'channelId',
          payloadName: 'savedMessagesResponse.results[$i]',
        ),
        channelName:
            readOptionalConversationPayloadString(itemMap['channelName']),
        surface: readOptionalConversationPayloadString(itemMap['surface']),
        savedAt: _tryParseDateTime(itemMap['savedAt']),
      ));
    }

    return SavedMessagesPage(items: items, hasMore: hasMore);
  }

  Set<String> _parseCheckResponse(Object? payload) {
    final map = requireConversationPayloadMap(
      payload,
      payloadName: 'savedCheckResponse',
    );
    final savedIds = map['savedIds'];
    if (savedIds is! List) return {};
    return savedIds.whereType<String>().where((s) => s.isNotEmpty).toSet();
  }

  DateTime? _tryParseDateTime(Object? value) {
    final raw = readOptionalConversationPayloadString(value);
    return raw != null ? DateTime.tryParse(raw) : null;
  }
}
