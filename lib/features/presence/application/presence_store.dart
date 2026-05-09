import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Possible presence statuses for a user.
enum UserPresenceStatus {
  online,
  offline,
}

/// Immutable state holding the set of currently-online user IDs.
@immutable
class PresenceState {
  const PresenceState({
    this.onlineUserIds = const {},
  });

  /// Set of user IDs currently online.
  final Set<String> onlineUserIds;

  /// Returns `true` if the user with [userId] is currently online.
  bool isOnline(String userId) => onlineUserIds.contains(userId);

  /// Returns the [UserPresenceStatus] for the given [userId].
  UserPresenceStatus statusOf(String userId) => onlineUserIds.contains(userId)
      ? UserPresenceStatus.online
      : UserPresenceStatus.offline;

  PresenceState copyWith({Set<String>? onlineUserIds}) {
    return PresenceState(
      onlineUserIds: onlineUserIds ?? this.onlineUserIds,
    );
  }
}

final presenceStoreProvider =
    NotifierProvider.autoDispose<PresenceStore, PresenceState>(
  PresenceStore.new,
);

class PresenceStore extends AutoDisposeNotifier<PresenceState> {
  @override
  PresenceState build() => const PresenceState();

  /// Mark a single user as online.
  void setOnline(String userId) {
    if (state.onlineUserIds.contains(userId)) return;
    state = state.copyWith(onlineUserIds: {...state.onlineUserIds, userId});
  }

  /// Mark a single user as offline.
  void setOffline(String userId) {
    if (!state.onlineUserIds.contains(userId)) return;
    final updated = Set<String>.of(state.onlineUserIds)..remove(userId);
    state = state.copyWith(onlineUserIds: updated);
  }

  /// Replace the entire online set with the given list of user IDs.
  ///
  /// Used when receiving a `presence:list` event that provides
  /// the full set of currently-online users.
  void setOnlineList(List<String> userIds) {
    state = state.copyWith(onlineUserIds: Set<String>.of(userIds));
  }

  /// Remove all presence data.
  void clearAll() {
    state = const PresenceState();
  }
}
