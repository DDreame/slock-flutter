import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Possible presence statuses for a user.
enum UserPresenceStatus {
  online,
  idle,
  offline,
}

/// Immutable state holding user presence information.
///
/// Uses a monotonic [generation] counter for O(1) equality instead of
/// O(n) mapEquals on [statuses]. Each mutation in [PresenceStore] produces
/// a new generation, so two instances are equal iff they are the same
/// generation (or both empty with generation 0).
@immutable
class PresenceState {
  const PresenceState({
    this.statuses = const {},
    this.generation = 0,
  });

  /// Map from user ID to their current presence status.
  final Map<String, UserPresenceStatus> statuses;

  /// Monotonic counter incremented on each mutation. Enables O(1) equality.
  final int generation;

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

  PresenceState copyWith({
    Map<String, UserPresenceStatus>? statuses,
    int? generation,
  }) {
    return PresenceState(
      statuses: statuses ?? this.statuses,
      generation: generation ?? this.generation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PresenceState &&
          runtimeType == other.runtimeType &&
          generation == other.generation;

  @override
  int get hashCode => generation.hashCode;
}

final presenceStoreProvider =
    NotifierProvider.autoDispose<PresenceStore, PresenceState>(
  PresenceStore.new,
);

class PresenceStore extends AutoDisposeNotifier<PresenceState> {
  int _generation = 0;

  @override
  bool updateShouldNotify(PresenceState previous, PresenceState next) =>
      previous != next;
  @override
  PresenceState build() => const PresenceState();

  /// Mark a single user as online.
  void setOnline(String userId) {
    if (state.statuses[userId] == UserPresenceStatus.online) return;
    _generation++;
    state = state.copyWith(
      statuses: {...state.statuses, userId: UserPresenceStatus.online},
      generation: _generation,
    );
  }

  /// Mark a single user as idle.
  void setIdle(String userId) {
    if (state.statuses[userId] == UserPresenceStatus.idle) return;
    _generation++;
    state = state.copyWith(
      statuses: {...state.statuses, userId: UserPresenceStatus.idle},
      generation: _generation,
    );
  }

  /// Mark a single user as offline.
  void setOffline(String userId) {
    final current = state.statuses[userId];
    if (current == null || current == UserPresenceStatus.offline) return;
    _generation++;
    final updated = Map<String, UserPresenceStatus>.of(state.statuses)
      ..remove(userId);
    state = state.copyWith(statuses: updated, generation: _generation);
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
      _generation++;
      state = state.copyWith(
        statuses: {...state.statuses, userId: status},
        generation: _generation,
      );
    }
  }

  /// Replace the entire status map with the given list of online user IDs.
  ///
  /// Used when receiving a bulk presence snapshot.
  void setOnlineList(List<String> userIds) {
    _generation++;
    state = state.copyWith(
      statuses: {
        for (final id in userIds) id: UserPresenceStatus.online,
      },
      generation: _generation,
    );
  }

  /// Remove all presence data.
  void clearAll() {
    _generation++;
    state = PresenceState(generation: _generation);
  }

  static UserPresenceStatus _parsePresenceLabel(String? label) {
    return switch (label) {
      'online' => UserPresenceStatus.online,
      'idle' => UserPresenceStatus.idle,
      _ => UserPresenceStatus.offline,
    };
  }
}
