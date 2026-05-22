import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';

final channelManagementStoreProvider = NotifierProvider.autoDispose<
    ChannelManagementStore, ChannelManagementState>(
  ChannelManagementStore.new,
);

class ChannelManagementStore
    extends AutoDisposeNotifier<ChannelManagementState> {
  Future<String>? _createInFlight;
  final Set<String> _operationKeys = <String>{};

  @override
  ChannelManagementState build() => const ChannelManagementState();

  Future<String> createChannel(
    String name, {
    required ServerScopeId serverId,
    String? description,
    bool? isPrivate,
  }) {
    final inFlight = _createInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _createChannel(
      name,
      serverId: serverId,
      description: description,
      isPrivate: isPrivate,
    ).whenComplete(() => _createInFlight = null);
    _createInFlight = future;
    return future;
  }

  Future<String> _createChannel(
    String name, {
    required ServerScopeId serverId,
    String? description,
    bool? isPrivate,
  }) async {
    state = state.copyWith(
      activeAction: ChannelManagementAction.create,
      clearFailure: true,
      clearAction: false,
    );

    try {
      final channelId =
          await ref.read(channelManagementRepositoryProvider).createChannel(
                serverId,
                name: name,
                description: description,
                isPrivate: isPrivate,
              );
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
    final operationKey = 'edit:${scopeId.value}';
    if (!_operationKeys.add(operationKey)) return;
    try {
      await _renameChannel(scopeId, name: name);
    } finally {
      _operationKeys.remove(operationKey);
    }
  }

  Future<void> _renameChannel(
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
    final operationKey = 'delete:${scopeId.value}';
    if (!_operationKeys.add(operationKey)) return;
    try {
      await _deleteChannel(scopeId);
    } finally {
      _operationKeys.remove(operationKey);
    }
  }

  Future<void> _deleteChannel(ChannelScopeId scopeId) async {
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
    final operationKey = 'leave:${scopeId.value}';
    if (!_operationKeys.add(operationKey)) return;
    try {
      await _leaveChannel(scopeId);
    } finally {
      _operationKeys.remove(operationKey);
    }
  }

  Future<void> _leaveChannel(ChannelScopeId scopeId) async {
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

  Future<void> _refreshHomeList() {
    return ref.read(homeListStoreProvider.notifier).load();
  }
}
