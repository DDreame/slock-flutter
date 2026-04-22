import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';

final channelManagementStoreProvider = NotifierProvider.autoDispose<
    ChannelManagementStore, ChannelManagementState>(
  ChannelManagementStore.new,
);

class ChannelManagementStore
    extends AutoDisposeNotifier<ChannelManagementState> {
  @override
  ChannelManagementState build() => const ChannelManagementState();

  Future<String?> createChannel(String name) async {
    final serverId = _requireServerId();
    state = state.copyWith(
      activeAction: ChannelManagementAction.create,
      clearFailure: true,
      clearAction: false,
    );

    try {
      final channelId = await ref
          .read(channelManagementRepositoryProvider)
          .createChannel(serverId, name: name);
      await _refreshHomeList();
      state = state.copyWith(clearAction: true, clearFailure: true);
      return channelId;
    } on AppFailure catch (failure) {
      state = state.copyWith(
        failure: failure,
        clearAction: true,
      );
      rethrow;
    }
  }

  Future<void> renameChannel(
    ChannelScopeId scopeId, {
    required String name,
  }) async {
    state = state.copyWith(
      activeAction: ChannelManagementAction.edit,
      channelId: scopeId.value,
      clearFailure: true,
    );

    try {
      await ref.read(channelManagementRepositoryProvider).updateChannel(
            scopeId.serverId,
            channelId: scopeId.value,
            name: name,
          );
      await _refreshHomeList();
      state = state.copyWith(clearAction: true, clearFailure: true);
    } on AppFailure catch (failure) {
      state = state.copyWith(
        failure: failure,
        clearAction: true,
      );
      rethrow;
    }
  }

  Future<void> deleteChannel(ChannelScopeId scopeId) async {
    state = state.copyWith(
      activeAction: ChannelManagementAction.delete,
      channelId: scopeId.value,
      clearFailure: true,
    );

    try {
      await ref.read(channelManagementRepositoryProvider).deleteChannel(
            scopeId.serverId,
            channelId: scopeId.value,
          );
      await _refreshHomeList();
      state = state.copyWith(clearAction: true, clearFailure: true);
    } on AppFailure catch (failure) {
      state = state.copyWith(
        failure: failure,
        clearAction: true,
      );
      rethrow;
    }
  }

  Future<void> leaveChannel(ChannelScopeId scopeId) async {
    state = state.copyWith(
      activeAction: ChannelManagementAction.leave,
      channelId: scopeId.value,
      clearFailure: true,
    );

    try {
      await ref.read(channelManagementRepositoryProvider).leaveChannel(
            scopeId.serverId,
            channelId: scopeId.value,
          );
      await _refreshHomeList();
      state = state.copyWith(clearAction: true, clearFailure: true);
    } on AppFailure catch (failure) {
      state = state.copyWith(
        failure: failure,
        clearAction: true,
      );
      rethrow;
    }
  }

  ServerScopeId _requireServerId() {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId != null) {
      return serverId;
    }
    throw const UnknownFailure(message: 'No active server selected.');
  }

  Future<void> _refreshHomeList() {
    return ref.read(homeListStoreProvider.notifier).load();
  }
}
