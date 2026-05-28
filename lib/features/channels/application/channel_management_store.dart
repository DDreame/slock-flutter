import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';

final channelManagementStoreProvider = NotifierProvider.autoDispose<
    ChannelManagementStore, ChannelManagementState>(
  ChannelManagementStore.new,
);

class ChannelManagementStore
    extends AutoDisposeNotifier<ChannelManagementState> {
  final Map<_CreateChannelRequest, Future<String>> _createInFlight =
      <_CreateChannelRequest, Future<String>>{};
  final Set<String> _operationKeys = <String>{};

  @override
  ChannelManagementState build() => const ChannelManagementState();

  Future<String> createChannel(
    String name, {
    required ServerScopeId serverId,
    String? description,
    bool? isPrivate,
  }) {
    final request = (
      serverId: serverId,
      name: name,
      description: description,
      isPrivate: isPrivate,
    );
    final inFlight = _createInFlight[request];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _createChannel(
      name,
      serverId: serverId,
      description: description,
      isPrivate: isPrivate,
    ).whenComplete(() {
      _createInFlight.remove(request);
    });
    _createInFlight[request] = future;
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
      _setStateIfMounted(
        (current) => current.copyWith(clearAction: true, clearFailure: true),
      );
      return channelId;
    } on AppFailure catch (failure) {
      _setStateIfMounted(
        (current) => current.copyWith(
          failure: failure,
          clearAction: true,
        ),
      );
      rethrow;
    } catch (error) {
      _setStateIfMounted(
        (current) => current.copyWith(
          failure: UnknownFailure(
            message: 'Channel operation failed.',
            causeType: error.runtimeType.toString(),
          ),
          clearAction: true,
        ),
      );
      rethrow;
    }
  }

  Future<bool> renameChannel(
    ChannelScopeId scopeId, {
    required String name,
  }) async {
    return updateChannel(scopeId, name: name);
  }

  /// Updates a channel's name, description, and/or privacy setting.
  /// At least one field must be non-null.
  Future<bool> updateChannel(
    ChannelScopeId scopeId, {
    String? name,
    String? description,
    bool? isPrivate,
  }) async {
    if (state.isBusy) return false;
    final operationKey = 'edit:${scopeId.value}';
    if (!_operationKeys.add(operationKey)) return false;
    try {
      await _updateChannel(
        scopeId,
        name: name,
        description: description,
        isPrivate: isPrivate,
      );
      return true;
    } finally {
      _operationKeys.remove(operationKey);
    }
  }

  Future<void> _updateChannel(
    ChannelScopeId scopeId, {
    String? name,
    String? description,
    bool? isPrivate,
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
            description: description,
            isPrivate: isPrivate,
          );
      await _refreshHomeList();
      _setStateIfMounted(
        (current) => current.copyWith(clearAction: true, clearFailure: true),
      );
    } on AppFailure catch (failure) {
      _setStateIfMounted(
        (current) => current.copyWith(
          failure: failure,
          clearAction: true,
        ),
      );
      rethrow;
    } catch (error) {
      _setStateIfMounted(
        (current) => current.copyWith(
          failure: UnknownFailure(
            message: 'Channel operation failed.',
            causeType: error.runtimeType.toString(),
          ),
          clearAction: true,
        ),
      );
      rethrow;
    }
  }

  Future<bool> deleteChannel(ChannelScopeId scopeId) async {
    if (state.isBusy) return false;
    final operationKey = 'delete:${scopeId.value}';
    if (!_operationKeys.add(operationKey)) return false;
    try {
      await _deleteChannel(scopeId);
      return true;
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
      _setStateIfMounted(
        (current) => current.copyWith(clearAction: true, clearFailure: true),
      );
    } on AppFailure catch (failure) {
      _setStateIfMounted(
        (current) => current.copyWith(
          failure: failure,
          clearAction: true,
        ),
      );
      rethrow;
    } catch (error) {
      _setStateIfMounted(
        (current) => current.copyWith(
          failure: UnknownFailure(
            message: 'Channel operation failed.',
            causeType: error.runtimeType.toString(),
          ),
          clearAction: true,
        ),
      );
      rethrow;
    }
  }

  Future<bool> leaveChannel(ChannelScopeId scopeId) async {
    if (state.isBusy) return false;
    final operationKey = 'leave:${scopeId.value}';
    if (!_operationKeys.add(operationKey)) return false;
    try {
      await _leaveChannel(scopeId);
      return true;
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
      _setStateIfMounted(
        (current) => current.copyWith(clearAction: true, clearFailure: true),
      );
    } on AppFailure catch (failure) {
      _setStateIfMounted(
        (current) => current.copyWith(
          failure: failure,
          clearAction: true,
        ),
      );
      rethrow;
    } catch (error) {
      _setStateIfMounted(
        (current) => current.copyWith(
          failure: UnknownFailure(
            message: 'Channel operation failed.',
            causeType: error.runtimeType.toString(),
          ),
          clearAction: true,
        ),
      );
      rethrow;
    }
  }

  Future<void> _refreshHomeList() async {
    try {
      await ref.read(homeListStoreProvider.notifier).load();
    } on StateError {
      return;
    }
  }

  Future<void> _refreshAgents() async {
    try {
      await ref.read(agentsStoreProvider.notifier).load();
    } on StateError {
      return;
    }
  }

  void _setStateIfMounted(
    ChannelManagementState Function(ChannelManagementState current) update,
  ) {
    try {
      state = update(state);
    } on StateError {
      return;
    }
  }

  Future<bool> stopAllAgents(ChannelScopeId scopeId) async {
    if (state.isBusy) return false;
    final operationKey = 'stopAgents:${scopeId.value}';
    if (!_operationKeys.add(operationKey)) return false;
    try {
      await _stopAllAgents(scopeId);
      return true;
    } finally {
      _operationKeys.remove(operationKey);
    }
  }

  Future<void> _stopAllAgents(ChannelScopeId scopeId) async {
    state = state.copyWith(
      activeAction: ChannelManagementAction.stopAgents,
      channelId: scopeId.value,
      clearFailure: true,
    );

    try {
      await ref.read(channelManagementRepositoryProvider).stopAllAgents(
            scopeId.serverId,
            channelId: scopeId.value,
          );
      await _refreshAgents();
      _setStateIfMounted(
        (current) => current.copyWith(clearAction: true, clearFailure: true),
      );
    } on AppFailure catch (failure) {
      _setStateIfMounted(
        (current) => current.copyWith(
          failure: failure,
          clearAction: true,
        ),
      );
      rethrow;
    } catch (error) {
      _setStateIfMounted(
        (current) => current.copyWith(
          failure: UnknownFailure(
            message: 'Channel operation failed.',
            causeType: error.runtimeType.toString(),
          ),
          clearAction: true,
        ),
      );
      rethrow;
    }
  }

  Future<bool> resumeAllAgents(ChannelScopeId scopeId) async {
    if (state.isBusy) return false;
    final operationKey = 'resumeAgents:${scopeId.value}';
    if (!_operationKeys.add(operationKey)) return false;
    try {
      await _resumeAllAgents(scopeId);
      return true;
    } finally {
      _operationKeys.remove(operationKey);
    }
  }

  Future<void> _resumeAllAgents(ChannelScopeId scopeId) async {
    state = state.copyWith(
      activeAction: ChannelManagementAction.resumeAgents,
      channelId: scopeId.value,
      clearFailure: true,
    );

    try {
      await ref.read(channelManagementRepositoryProvider).resumeAllAgents(
            scopeId.serverId,
            channelId: scopeId.value,
          );
      await _refreshAgents();
      _setStateIfMounted(
        (current) => current.copyWith(clearAction: true, clearFailure: true),
      );
    } on AppFailure catch (failure) {
      _setStateIfMounted(
        (current) => current.copyWith(
          failure: failure,
          clearAction: true,
        ),
      );
      rethrow;
    } catch (error) {
      _setStateIfMounted(
        (current) => current.copyWith(
          failure: UnknownFailure(
            message: 'Channel operation failed.',
            causeType: error.runtimeType.toString(),
          ),
          clearAction: true,
        ),
      );
      rethrow;
    }
  }
}

typedef _CreateChannelRequest = ({
  ServerScopeId serverId,
  String name,
  String? description,
  bool? isPrivate,
});
