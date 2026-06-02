import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';

/// Use-case provider that fetches invite preview information.
///
/// Wraps [ServerListRepository.getInviteInfo] to keep the presentation layer
/// decoupled from the data layer (layer violation cleanup — scan #57).
final getInviteInfoUseCaseProvider =
    Provider.autoDispose<GetInviteInfoUseCase>((ref) {
  final repo = ref.watch(serverListRepositoryProvider);
  return GetInviteInfoUseCase(repo);
});

class GetInviteInfoUseCase {
  const GetInviteInfoUseCase(this._repo);

  final ServerListRepository _repo;

  Future<InviteInfo> call(String token) {
    return _repo.getInviteInfo(token);
  }
}
