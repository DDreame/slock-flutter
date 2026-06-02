import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/channel_files_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

/// Fetches the list of files shared in a channel.
///
/// Thin application-layer wrapper around [ChannelFilesRepository.listFiles].
/// Presentation code should use this instead of importing the repository
/// provider directly.
final listChannelFilesUseCaseProvider = Provider<
    Future<List<MessageAttachment>> Function(
      ServerScopeId serverId, {
      required String channelId,
    })>((ref) {
  return (ServerScopeId serverId, {required String channelId}) =>
      ref.read(channelFilesRepositoryProvider).listFiles(
            serverId,
            channelId: channelId,
          );
});
