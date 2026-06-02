import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';

/// Use-case provider that loads a member profile by server + user ID.
///
/// Wraps [ProfileRepository.loadProfile] to keep the presentation layer
/// decoupled from the data layer (layer violation cleanup — scan #57).
final loadProfileUseCaseProvider =
    Provider.autoDispose<LoadProfileUseCase>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return LoadProfileUseCase(repo);
});

class LoadProfileUseCase {
  const LoadProfileUseCase(this._repo);

  final ProfileRepository _repo;

  Future<MemberProfile> call(
    ServerScopeId serverId, {
    required String userId,
  }) {
    return _repo.loadProfile(serverId, userId: userId);
  }
}
