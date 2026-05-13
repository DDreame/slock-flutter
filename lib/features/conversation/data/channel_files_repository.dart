import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

/// Repository for fetching the list of files shared in a channel.
abstract class ChannelFilesRepository {
  /// Returns all files (attachments) shared in the given channel,
  /// sorted newest-first (INV-FILES-1).
  Future<List<MessageAttachment>> listFiles(
    ServerScopeId serverId, {
    required String channelId,
  });
}
