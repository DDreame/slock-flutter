import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/available_channel.dart';
import 'package:slock_app/features/channels/data/channel_management_repository.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';

/// Use-case provider that loads available (joinable) channels for a server.
///
/// Wraps [ChannelManagementRepository.loadAvailableChannels] to keep the
/// presentation layer decoupled from the data layer.
final loadAvailableChannelsUseCaseProvider =
    Provider.autoDispose<LoadAvailableChannelsUseCase>((ref) {
  final repo = ref.watch(channelManagementRepositoryProvider);
  return LoadAvailableChannelsUseCase(repo);
});

class LoadAvailableChannelsUseCase {
  const LoadAvailableChannelsUseCase(this._repo);

  final ChannelManagementRepository _repo;

  Future<List<AvailableChannel>> call(ServerScopeId serverId) {
    return _repo.loadAvailableChannels(serverId);
  }
}
