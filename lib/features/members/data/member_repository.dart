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

  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  });
}

abstract class MemberInviteMutationRepository {
  Future<void> inviteByEmail(
    ServerScopeId serverId, {
    required String email,
  });
}

extension MemberRepositoryInviteX on MemberRepository {
  MemberInviteMutationRepository get _inviteRepository {
    final repository = this;
    if (repository is MemberInviteMutationRepository) {
      return repository as MemberInviteMutationRepository;
    }
    throw UnsupportedError('Member invite-by-email is not implemented');
  }

  Future<void> inviteByEmail(
    ServerScopeId serverId, {
    required String email,
  }) {
    return _inviteRepository.inviteByEmail(serverId, email: email);
  }
}
