import 'package:slock_app/core/core.dart';

abstract class ChannelManagementRepository {
  Future<String?> createChannel(
    ServerScopeId serverId, {
    required String name,
  });

  Future<void> updateChannel(
    ServerScopeId serverId, {
    required String channelId,
    required String name,
  });

  Future<void> deleteChannel(
    ServerScopeId serverId, {
    required String channelId,
  });

  Future<void> leaveChannel(
    ServerScopeId serverId, {
    required String channelId,
  });
}
