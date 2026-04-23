import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';

enum ChannelMemberStatus { initial, loading, success, failure }

@immutable
class ChannelMemberState {
  const ChannelMemberState({
    this.status = ChannelMemberStatus.initial,
    this.items = const [],
    this.failure,
  });

  final ChannelMemberStatus status;
  final List<ChannelMember> items;
  final AppFailure? failure;

  ChannelMemberState copyWith({
    ChannelMemberStatus? status,
    List<ChannelMember>? items,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return ChannelMemberState(
      status: status ?? this.status,
      items: items ?? this.items,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChannelMemberState &&
            runtimeType == other.runtimeType &&
            status == other.status &&
            listEquals(items, other.items) &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(status, Object.hashAll(items), failure);
}
