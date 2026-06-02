import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/conversation/presentation/utils/mention_profile_resolver.dart';

/// Use-case provider that resolves an @mention handle to a profile route.
///
/// Wraps [resolveMentionProfileRoute] to keep the presentation layer
/// decoupled from the channel member data layer (layer violation cleanup —
/// scan #57).
final resolveMentionProfileUseCaseProvider =
    Provider.autoDispose<ResolveMentionProfileUseCase>((ref) {
  final repo = ref.watch(channelMemberRepositoryProvider);
  return ResolveMentionProfileUseCase(repo);
});

class ResolveMentionProfileUseCase {
  const ResolveMentionProfileUseCase(this._repo);

  final ChannelMemberRepository _repo;

  /// Resolves [mentionName] to a profile navigation route string, or `null`
  /// if the mention cannot be resolved.
  Future<String?> call({
    required ServerScopeId serverId,
    required String channelId,
    required String mentionName,
  }) {
    return resolveMentionProfileRoute(
      memberRepo: _repo,
      serverId: serverId,
      channelId: channelId,
      mentionName: mentionName,
    );
  }
}
