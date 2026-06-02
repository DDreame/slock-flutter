import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';

/// Opens (or creates) a DM channel with a human user.
///
/// Returns the channelId of the DM. Presentation code should navigate
/// to that channel after calling this.
///
/// This thin use-case wrapper exists to prevent presentation-layer files
/// from importing repository providers directly (layer violation cleanup).
final openDmUseCaseProvider = Provider<
    Future<String> Function(ServerScopeId serverId, {required String userId})>(
  (ref) {
    return (ServerScopeId serverId, {required String userId}) =>
        ref.read(memberRepositoryProvider).openDirectMessage(
              serverId,
              userId: userId,
            );
  },
);

/// Opens (or creates) a DM channel with an agent.
///
/// Returns the channelId of the DM. Presentation code should navigate
/// to that channel after calling this.
final openAgentDmUseCaseProvider = Provider<
    Future<String> Function(ServerScopeId serverId, {required String agentId})>(
  (ref) {
    return (ServerScopeId serverId, {required String agentId}) =>
        ref.read(memberRepositoryProvider).openAgentDirectMessage(
              serverId,
              agentId: agentId,
            );
  },
);
