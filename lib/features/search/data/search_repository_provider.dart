import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/search/data/search_repository.dart';

const _searchPath = '/messages/search';
const _serverHeaderName = 'X-Server-Id';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiSearchRepository(appDioClient: appDioClient);
});

class _ApiSearchRepository implements SearchRepository {
  const _ApiSearchRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<SearchResultsPage> searchMessages(
    ServerScopeId serverId,
    String query,
  ) async {
    try {
      final response = await _appDioClient.get<Object?>(
        _searchPath,
        queryParameters: {
          'query': query,
          'serverId': serverId.value,
        },
        options: Options(headers: {_serverHeaderName: serverId.routeParam}),
      );
      return _parseSearchResponse(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to search messages.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  SearchResultsPage _parseSearchResponse(Object? payload) {
    final map = requireConversationPayloadMap(
      payload,
      payloadName: 'searchResponse',
    );
    final results = map['results'];
    final hasMore = map['hasMore'] == true;

    if (results is! List) {
      return const SearchResultsPage(messages: [], hasMore: false);
    }

    final messages = <SearchResultMessage>[];
    for (var i = 0; i < results.length; i++) {
      final item = results[i];
      if (item is! Map) continue;
      final itemMap =
          item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
      final message = parseConversationMessageSummary(
        itemMap,
        payloadName: 'searchResponse.results[$i]',
      );
      messages.add(SearchResultMessage(
        message: message,
        channelId: readOptionalConversationPayloadString(itemMap['channelId']),
        channelName:
            readOptionalConversationPayloadString(itemMap['channelName']),
      ));
    }

    return SearchResultsPage(messages: messages, hasMore: hasMore);
  }
}
