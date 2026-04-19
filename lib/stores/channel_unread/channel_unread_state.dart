import 'package:flutter/foundation.dart';
import 'package:slock_app/core/scope/channel_scope_id.dart';
import 'package:slock_app/core/scope/direct_message_scope_id.dart';

@immutable
class ChannelUnreadState {
  const ChannelUnreadState({
    this.channelUnreadCounts = const {},
    this.dmUnreadCounts = const {},
  });

  final Map<ChannelScopeId, int> channelUnreadCounts;
  final Map<DirectMessageScopeId, int> dmUnreadCounts;

  int channelUnreadCount(ChannelScopeId scopeId) =>
      channelUnreadCounts[scopeId] ?? 0;

  int dmUnreadCount(DirectMessageScopeId scopeId) =>
      dmUnreadCounts[scopeId] ?? 0;

  bool hasChannelUnread(ChannelScopeId scopeId) =>
      channelUnreadCount(scopeId) > 0;

  bool hasDmUnread(DirectMessageScopeId scopeId) => dmUnreadCount(scopeId) > 0;

  int get totalUnreadCount =>
      channelUnreadCounts.values.fold(0, (sum, c) => sum + c) +
      dmUnreadCounts.values.fold(0, (sum, c) => sum + c);

  ChannelUnreadState copyWith({
    Map<ChannelScopeId, int>? channelUnreadCounts,
    Map<DirectMessageScopeId, int>? dmUnreadCounts,
  }) {
    return ChannelUnreadState(
      channelUnreadCounts: channelUnreadCounts ?? this.channelUnreadCounts,
      dmUnreadCounts: dmUnreadCounts ?? this.dmUnreadCounts,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChannelUnreadState &&
            runtimeType == other.runtimeType &&
            mapEquals(channelUnreadCounts, other.channelUnreadCounts) &&
            mapEquals(dmUnreadCounts, other.dmUnreadCounts);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(
          channelUnreadCounts.entries.map((e) => Object.hash(e.key, e.value)),
        ),
        Object.hashAll(
          dmUnreadCounts.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}
