import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

abstract class MemberRepository {
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId);

  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  });
}
