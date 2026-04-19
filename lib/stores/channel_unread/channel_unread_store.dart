import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/scope/channel_scope_id.dart';
import 'package:slock_app/core/scope/direct_message_scope_id.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_state.dart';

final channelUnreadStoreProvider =
    NotifierProvider<ChannelUnreadStore, ChannelUnreadState>(
  ChannelUnreadStore.new,
);

class ChannelUnreadStore extends Notifier<ChannelUnreadState> {
  @override
  ChannelUnreadState build() => const ChannelUnreadState();

  void hydrateChannelUnreads(Map<ChannelScopeId, int> counts) {
    state = state.copyWith(channelUnreadCounts: Map.unmodifiable(counts));
  }

  void hydrateDmUnreads(Map<DirectMessageScopeId, int> counts) {
    state = state.copyWith(dmUnreadCounts: Map.unmodifiable(counts));
  }

  void markChannelRead(ChannelScopeId scopeId) {
    if (!state.channelUnreadCounts.containsKey(scopeId)) return;
    final updated = Map<ChannelScopeId, int>.of(state.channelUnreadCounts)
      ..remove(scopeId);
    state = state.copyWith(channelUnreadCounts: Map.unmodifiable(updated));
  }

  void markDmRead(DirectMessageScopeId scopeId) {
    if (!state.dmUnreadCounts.containsKey(scopeId)) return;
    final updated = Map<DirectMessageScopeId, int>.of(state.dmUnreadCounts)
      ..remove(scopeId);
    state = state.copyWith(dmUnreadCounts: Map.unmodifiable(updated));
  }

  void incrementChannelUnread(ChannelScopeId scopeId, {int by = 1}) {
    final current = state.channelUnreadCount(scopeId);
    final updated = Map<ChannelScopeId, int>.of(state.channelUnreadCounts)
      ..[scopeId] = current + by;
    state = state.copyWith(channelUnreadCounts: Map.unmodifiable(updated));
  }

  void incrementDmUnread(DirectMessageScopeId scopeId, {int by = 1}) {
    final current = state.dmUnreadCount(scopeId);
    final updated = Map<DirectMessageScopeId, int>.of(state.dmUnreadCounts)
      ..[scopeId] = current + by;
    state = state.copyWith(dmUnreadCounts: Map.unmodifiable(updated));
  }

  void setChannelUnreadCount(ChannelScopeId scopeId, int count) {
    final updated = Map<ChannelScopeId, int>.of(state.channelUnreadCounts);
    if (count <= 0) {
      updated.remove(scopeId);
    } else {
      updated[scopeId] = count;
    }
    state = state.copyWith(channelUnreadCounts: Map.unmodifiable(updated));
  }

  void setDmUnreadCount(DirectMessageScopeId scopeId, int count) {
    final updated = Map<DirectMessageScopeId, int>.of(state.dmUnreadCounts);
    if (count <= 0) {
      updated.remove(scopeId);
    } else {
      updated[scopeId] = count;
    }
    state = state.copyWith(dmUnreadCounts: Map.unmodifiable(updated));
  }

  void clearAll() {
    state = const ChannelUnreadState();
  }
}
