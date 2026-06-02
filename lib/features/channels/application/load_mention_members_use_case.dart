import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';

/// Loads channel members for mention autocomplete.
///
/// Thin use-case wrapper so presentation code does not import
/// [channelMemberRepositoryProvider] directly.
final loadMentionMembersUseCaseProvider = Provider<
    Future<List<ChannelMember>> Function({
      required ServerScopeId serverId,
      required String channelId,
    })>((ref) {
  return ({
    required ServerScopeId serverId,
    required String channelId,
  }) async {
    final repo = ref.read(channelMemberRepositoryProvider);
    return repo.listMembers(serverId, channelId: channelId);
  };
});
