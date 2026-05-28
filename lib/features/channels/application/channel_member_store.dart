import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_member_state.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
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
  bool _disposed = false;

  @override
  ChannelMemberState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    // INV-834: Re-fetch on WebSocket reconnect — data may be stale.
    ref.listen(realtimeServiceProvider.select((s) => s.status), (prev, next) {
      if (prev == RealtimeConnectionStatus.reconnecting &&
          next == RealtimeConnectionStatus.connected) {
        if (state.status == ChannelMemberStatus.success) {
          load();
        }
      }
    });

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
      if (_disposed) return;
      state = state.copyWith(
        status: ChannelMemberStatus.success,
        items: members,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (_disposed) return;
      state = state.copyWith(
        status: ChannelMemberStatus.failure,
        failure: failure,
      );
    } catch (e, st) {
      if (_disposed) return;
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
      if (_disposed) return;
      await load();
    } on AppFailure catch (failure) {
      if (_disposed) return;
      state = state.copyWith(failure: failure);
      rethrow;
    } catch (error) {
      if (_disposed) return;
      state = state.copyWith(
        failure: UnknownFailure(
          message: 'Failed to add channel member.',
          causeType: error.runtimeType.toString(),
        ),
      );
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
      if (_disposed) return;
      await load();
    } on AppFailure catch (failure) {
      if (_disposed) return;
      state = state.copyWith(failure: failure);
      rethrow;
    } catch (error) {
      if (_disposed) return;
      state = state.copyWith(
        failure: UnknownFailure(
          message: 'Failed to add channel member.',
          causeType: error.runtimeType.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> removeHumanMember(String userId) async {
    final serverId = ref.read(currentChannelMemberServerIdProvider);
    final channelId = ref.read(currentChannelMemberChannelIdProvider);
    // INV-ROLLBACK-829: Snapshot item + index for per-item rollback.
    final removedIndex = state.items.indexWhere((m) => m.userId == userId);
    if (removedIndex < 0) return;
    final removedItem = state.items[removedIndex];
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
      if (_disposed) return;
      _reinsertAtPosition(removedItem, removedIndex);
      state = state.copyWith(failure: failure);
      rethrow;
    } catch (error) {
      if (_disposed) return;
      _reinsertAtPosition(removedItem, removedIndex);
      state = state.copyWith(
        failure: UnknownFailure(
          message: 'Failed to remove channel member.',
          causeType: error.runtimeType.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> removeAgentMember(String agentId) async {
    final serverId = ref.read(currentChannelMemberServerIdProvider);
    final channelId = ref.read(currentChannelMemberChannelIdProvider);
    // INV-ROLLBACK-829: Snapshot item + index for per-item rollback.
    final removedIndex = state.items.indexWhere((m) => m.agentId == agentId);
    if (removedIndex < 0) return;
    final removedItem = state.items[removedIndex];
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
      if (_disposed) return;
      _reinsertAtPosition(removedItem, removedIndex);
      state = state.copyWith(failure: failure);
      rethrow;
    } catch (error) {
      if (_disposed) return;
      _reinsertAtPosition(removedItem, removedIndex);
      state = state.copyWith(
        failure: UnknownFailure(
          message: 'Failed to remove channel member.',
          causeType: error.runtimeType.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Re-inserts [item] at [originalIndex], clamped to the current list length.
  /// Preserves ordering while tolerating concurrent list mutations.
  void _reinsertAtPosition(ChannelMember item, int originalIndex) {
    final current = [...state.items];
    final insertAt = originalIndex.clamp(0, current.length);
    current.insert(insertAt, item);
    state = state.copyWith(items: current);
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
