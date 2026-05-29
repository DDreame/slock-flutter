import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';

/// Resolves a mention handle to a profile navigation route.
///
/// Fetches channel members via [memberRepo], matches [mentionName]
/// (case-insensitive) against [ChannelMember.mentionHandle], and returns
/// the profile route path (`/servers/{serverId}/profile/{entityId}`).
///
/// Returns `null` when the mention cannot be resolved (member left,
/// no matching handle, or member has no entity ID). Callers should
/// treat `null` as a graceful no-op — no navigation, no error.
Future<String?> resolveMentionProfileRoute({
  required ChannelMemberRepository memberRepo,
  required ServerScopeId serverId,
  required String channelId,
  required String mentionName,
}) async {
  final members = await memberRepo.listMembers(
    serverId,
    channelId: channelId,
  );

  final mentionLower = mentionName.toLowerCase();
  final match = members
      .where((m) => m.mentionHandle.toLowerCase() == mentionLower)
      .firstOrNull;
  if (match == null) return null;

  final entityId = match.memberEntityId;
  if (entityId == null) return null;

  return '/servers/${serverId.value}/profile/$entityId';
}
