import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';

enum ChannelManagementAction { create, edit, delete, leave }

@immutable
class ChannelManagementState {
  const ChannelManagementState({
    this.activeAction,
    this.channelId,
    this.failure,
  });

  final ChannelManagementAction? activeAction;
  final String? channelId;
  final AppFailure? failure;

  bool get isBusy => activeAction != null;

  bool isRunning(
    ChannelManagementAction action, {
    String? channelId,
  }) {
    if (activeAction != action) {
      return false;
    }
    if (channelId == null) {
      return true;
    }
    return this.channelId == channelId;
  }

  ChannelManagementState copyWith({
    ChannelManagementAction? activeAction,
    String? channelId,
    AppFailure? failure,
    bool clearAction = false,
    bool clearFailure = false,
  }) {
    return ChannelManagementState(
      activeAction: clearAction ? null : (activeAction ?? this.activeAction),
      channelId: clearAction ? null : (channelId ?? this.channelId),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChannelManagementState &&
            runtimeType == other.runtimeType &&
            activeAction == other.activeAction &&
            channelId == other.channelId &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(activeAction, channelId, failure);
}
