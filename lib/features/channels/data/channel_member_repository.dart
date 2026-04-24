import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';

abstract class ChannelMemberRepository {
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  });

  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  });

  Future<void> addAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  });

  Future<void> removeHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  });

  Future<void> removeAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  });
}
