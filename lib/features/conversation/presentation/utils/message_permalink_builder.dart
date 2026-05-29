import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';

/// Host used for all permalink URLs.
const permalinkHost = 'app.slock.ai';

/// Builds a full permalink URL for a message.
///
/// When [threadContext] is provided, builds a thread permalink:
///   `https://app.slock.ai/servers/{serverId}/threads/{parentMessageId}/replies
///     ?channelId={parentChannelId}&messageId={messageId}`
///
/// Otherwise builds a channel or DM permalink:
///   `https://app.slock.ai/servers/{serverId}/{channels|dms}/{channelId}
///     ?messageId={messageId}`
String buildMessagePermalink({
  required ConversationDetailTarget target,
  required String messageId,
  ThreadRouteTarget? threadContext,
}) {
  final serverId = target.serverId.value;

  if (threadContext != null) {
    return Uri(
      scheme: 'https',
      host: permalinkHost,
      path:
          '/servers/$serverId/threads/${threadContext.parentMessageId}/replies',
      queryParameters: {
        'channelId': threadContext.parentChannelId,
        'messageId': messageId,
      },
    ).toString();
  }

  final segment =
      target.surface == ConversationSurface.channel ? 'channels' : 'dms';
  return Uri(
    scheme: 'https',
    host: permalinkHost,
    path: '/servers/$serverId/$segment/${target.conversationId}',
    queryParameters: {'messageId': messageId},
  ).toString();
}
