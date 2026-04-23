import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

abstract class MemberRepository {
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId);

  Future<String> createInvite(ServerScopeId serverId);

  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  });

  Future<void> removeMember(ServerScopeId serverId, {required String userId});

  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  });
}
