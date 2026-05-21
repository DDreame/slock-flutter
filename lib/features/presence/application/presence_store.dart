import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Possible presence statuses for a user.
enum UserPresenceStatus {
  online,
  idle,
  offline,
}

/// Immutable state holding user presence information.
@immutable
class PresenceState {
  const PresenceState({
    this.statuses = const {},
  });

  /// Map from user ID to their current presence status.
  final Map<String, UserPresenceStatus> statuses;

  /// Convenience: set of user IDs that are online.
  Set<String> get onlineUserIds => {
        for (final entry in statuses.entries)
          if (entry.value == UserPresenceStatus.online) entry.key,
      };

  /// Returns `true` if the user with [userId] is currently online.
  bool isOnline(String userId) => statuses[userId] == UserPresenceStatus.online;

  /// Returns the [UserPresenceStatus] for the given [userId].
  UserPresenceStatus statusOf(String userId) =>
      statuses[userId] ?? UserPresenceStatus.offline;

  PresenceState copyWith({Map<String, UserPresenceStatus>? statuses}) {
    return PresenceState(
      statuses: statuses ?? this.statuses,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PresenceState &&
          runtimeType == other.runtimeType &&
          mapEquals(statuses, other.statuses);

  @override
  int get hashCode {
    // XOR of entry hashes — order-independent.
    var h = 0;
    for (final entry in statuses.entries) {
      h ^= Object.hash(entry.key, entry.value);
    }
    return h;
  }
}

final presenceStoreProvider =
    NotifierProvider.autoDispose<PresenceStore, PresenceState>(
  PresenceStore.new,
);

class PresenceStore extends AutoDisposeNotifier<PresenceState> {
  @override
  bool updateShouldNotify(PresenceState previous, PresenceState next) =>
      previous != next;
  @override
  PresenceState build() => const PresenceState();

  /// Mark a single user as online.
  void setOnline(String userId) {
    if (state.statuses[userId] == UserPresenceStatus.online) return;
    state = state.copyWith(
      statuses: {...state.statuses, userId: UserPresenceStatus.online},
    );
  }

  /// Mark a single user as idle.
  void setIdle(String userId) {
    if (state.statuses[userId] == UserPresenceStatus.idle) return;
    state = state.copyWith(
      statuses: {...state.statuses, userId: UserPresenceStatus.idle},
    );
  }

  /// Mark a single user as offline.
  void setOffline(String userId) {
    final current = state.statuses[userId];
    if (current == null || current == UserPresenceStatus.offline) return;
    final updated = Map<String, UserPresenceStatus>.of(state.statuses)
      ..remove(userId);
    state = state.copyWith(statuses: updated);
  }

  /// Set presence status for a user from a string label.
  ///
  /// Maps `'online'` → [UserPresenceStatus.online],
  /// `'idle'` → [UserPresenceStatus.idle],
  /// anything else → [UserPresenceStatus.offline].
  void setPresence(String userId, String? presenceLabel) {
    final status = _parsePresenceLabel(presenceLabel);
    if (status == UserPresenceStatus.offline) {
      setOffline(userId);
    } else {
      // Short-circuit: skip allocation when value is unchanged.
      if (state.statuses[userId] == status) return;
      state = state.copyWith(
        statuses: {...state.statuses, userId: status},
      );
    }
  }

  /// Replace the entire status map with the given list of online user IDs.
  ///
  /// Used when receiving a bulk presence snapshot.
  void setOnlineList(List<String> userIds) {
    state = state.copyWith(
      statuses: {
        for (final id in userIds) id: UserPresenceStatus.online,
      },
    );
  }

  /// Remove all presence data.
  void clearAll() {
    state = const PresenceState();
  }

  static UserPresenceStatus _parsePresenceLabel(String? label) {
    return switch (label) {
      'online' => UserPresenceStatus.online,
      'idle' => UserPresenceStatus.idle,
      _ => UserPresenceStatus.offline,
    };
  }
}
