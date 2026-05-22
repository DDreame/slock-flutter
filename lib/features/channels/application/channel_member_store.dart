import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_member_state.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';

final currentChannelMemberServerIdProvider = Provider<ServerScopeId>((ref) {
  throw UnimplementedError(
    'currentChannelMemberServerIdProvider must be overridden.',
  );
});

final currentChannelMemberChannelIdProvider = Provider<String>((ref) {
  throw UnimplementedError(
    'currentChannelMemberChannelIdProvider must be overridden.',
  );
});

final channelMemberStoreProvider =
    NotifierProvider.autoDispose<ChannelMemberStore, ChannelMemberState>(
  ChannelMemberStore.new,
  dependencies: [
    currentChannelMemberServerIdProvider,
    currentChannelMemberChannelIdProvider,
  ],
);

class ChannelMemberStore extends AutoDisposeNotifier<ChannelMemberState> {
  @override
  ChannelMemberState build() {
    return const ChannelMemberState();
  }

  /// Idempotent load guard — only fires [load] when status is initial.
  /// Prevents redundant network requests when the page is revisited or
  /// the store is already populated.
  void ensureLoaded() {
    if (state.status == ChannelMemberStatus.initial) {
      load();
    }
  }

  Future<void> load() async {
    final serverId = ref.read(currentChannelMemberServerIdProvider);
    final channelId = ref.read(currentChannelMemberChannelIdProvider);
    state = state.copyWith(
      status: ChannelMemberStatus.loading,
      clearFailure: true,
    );

    try {
      final repo = ref.read(channelMemberRepositoryProvider);
      final members = await repo.listMembers(serverId, channelId: channelId);
      state = state.copyWith(
        status: ChannelMemberStatus.success,
        items: members,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        status: ChannelMemberStatus.failure,
        failure: failure,
      );
    } catch (e, st) {
      _reportUnexpectedError('load', e, st);
      state = state.copyWith(
        status: ChannelMemberStatus.failure,
        failure: UnknownFailure(
          message: 'Failed to load channel members.',
          causeType: e.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> addHumanMember(String userId) async {
    final serverId = ref.read(currentChannelMemberServerIdProvider);
    final channelId = ref.read(currentChannelMemberChannelIdProvider);
    final repo = ref.read(channelMemberRepositoryProvider);
    state = state.copyWith(clearFailure: true);
    try {
      await repo.addHumanMember(
        serverId,
        channelId: channelId,
        userId: userId,
      );
      await load();
    } on AppFailure catch (failure) {
      state = state.copyWith(failure: failure);
      rethrow;
    }
  }

  Future<void> addAgentMember(String agentId) async {
    final serverId = ref.read(currentChannelMemberServerIdProvider);
    final channelId = ref.read(currentChannelMemberChannelIdProvider);
    final repo = ref.read(channelMemberRepositoryProvider);
    state = state.copyWith(clearFailure: true);
    try {
      await repo.addAgentMember(
        serverId,
        channelId: channelId,
        agentId: agentId,
      );
      await load();
    } on AppFailure catch (failure) {
      state = state.copyWith(failure: failure);
      rethrow;
    }
  }

  Future<void> removeHumanMember(String userId) async {
    final serverId = ref.read(currentChannelMemberServerIdProvider);
    final channelId = ref.read(currentChannelMemberChannelIdProvider);
    final previousItems = state.items;
    state = state.copyWith(
      items: state.items.where((m) => m.userId != userId).toList(),
    );

    try {
      final repo = ref.read(channelMemberRepositoryProvider);
      await repo.removeHumanMember(
        serverId,
        channelId: channelId,
        userId: userId,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(items: previousItems, failure: failure);
      rethrow;
    }
  }

  Future<void> removeAgentMember(String agentId) async {
    final serverId = ref.read(currentChannelMemberServerIdProvider);
    final channelId = ref.read(currentChannelMemberChannelIdProvider);
    final previousItems = state.items;
    state = state.copyWith(
      items: state.items.where((m) => m.agentId != agentId).toList(),
    );

    try {
      final repo = ref.read(channelMemberRepositoryProvider);
      await repo.removeAgentMember(
        serverId,
        channelId: channelId,
        agentId: agentId,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(items: previousItems, failure: failure);
      rethrow;
    }
  }

  Future<void> retry() => load();

  void _reportUnexpectedError(String method, Object error, StackTrace st) {
    try {
      ref.read(diagnosticsCollectorProvider).error(
        'ChannelMemberStore',
        '$method failed: $error',
        metadata: {'stackTrace': st.toString()},
      );
    } catch (_) {}
  }
}
