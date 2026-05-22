import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/data/conversation_unread_repository.dart';

const _serverHeaderName = 'X-Server-Id';
const _channelsPath = '/channels';
const _unreadSuffix = '/unread';

final conversationUnreadRepositoryProvider =
    Provider<ConversationUnreadRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiConversationUnreadRepository(appDioClient: appDioClient);
});

class _ApiConversationUnreadRepository implements ConversationUnreadRepository {
  _ApiConversationUnreadRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<void> markAsUnread(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    try {
      await _appDioClient.post<Object?>(
        '$_channelsPath/$channelId$_unreadSuffix',
        options: Options(headers: {_serverHeaderName: serverId.value}),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to mark conversation unread.',
        causeType: error.runtimeType.toString(),
      );
    }
  }
}
