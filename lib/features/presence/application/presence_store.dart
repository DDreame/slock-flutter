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
/// Content-based equality via [mapEquals] for correctness. The O(1) notification
/// optimization lives in [PresenceStore.updateShouldNotify] which uses the
/// [generation] counter to skip redundant notifications.
@immutable
class PresenceState {
  const PresenceState({
    this.statuses = const {},
    this.generation = 0,
  });

  /// Map from user ID to their current presence status.
  final Map<String, UserPresenceStatus> statuses;

  /// Monotonic counter incremented on each store mutation. Used by
  /// [PresenceStore.updateShouldNotify] for O(1) notification filtering.
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
          mapEquals(statuses, other.statuses);

  @override
  int get hashCode {
    final sortedKeys = statuses.keys.toList()..sort();
    return Object.hashAll(
      sortedKeys.map((key) => Object.hash(key, statuses[key])),
    );
  }
}

final presenceStoreProvider =
    NotifierProvider.autoDispose<PresenceStore, PresenceState>(
  PresenceStore.new,
);

class PresenceStore extends AutoDisposeNotifier<PresenceState> {
  static const maxPresenceStatuses = 500;

  int _generation = 0;
  final Map<String, int> _lastUpdatedGenerations = {};

  /// O(1) notification filtering via generation counter. When the store's
  /// own mutation methods are used, each produces a unique generation so this
  /// short-circuits to a cheap int comparison. Falls back to content equality
  /// for external state assignments (e.g. test helpers) that bypass generation.
  @override
  bool updateShouldNotify(PresenceState previous, PresenceState next) =>
      previous.generation != next.generation || previous != next;
  @override
  PresenceState build() => const PresenceState();

  /// Mark a single user as online.
  void setOnline(String userId) {
    if (state.statuses[userId] == UserPresenceStatus.online) return;
    _generation++;
    state = state.copyWith(
      statuses: _boundedStatuses({
        ...state.statuses,
        userId: UserPresenceStatus.online,
      }, touchedUserId: userId),
      generation: _generation,
    );
  }

  /// Mark a single user as idle.
  void setIdle(String userId) {
    if (state.statuses[userId] == UserPresenceStatus.idle) return;
    _generation++;
    state = state.copyWith(
      statuses: _boundedStatuses({
        ...state.statuses,
        userId: UserPresenceStatus.idle,
      }, touchedUserId: userId),
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
    _lastUpdatedGenerations.remove(userId);
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
        statuses: _boundedStatuses({
          ...state.statuses,
          userId: status,
        }, touchedUserId: userId),
        generation: _generation,
      );
    }
  }

  /// Replace the entire status map with the given list of online user IDs.
  ///
  /// Used when receiving a bulk presence snapshot.
  void setOnlineList(List<String> userIds) {
    _generation++;
    final next = {
      for (final id in userIds) id: UserPresenceStatus.online,
    };
    _lastUpdatedGenerations
      ..clear()
      ..addEntries(next.keys.map((id) => MapEntry(id, _generation)));
    state = state.copyWith(
      statuses: _boundedStatuses(next),
      generation: _generation,
    );
  }

  /// Remove all presence data.
  void clearAll() {
    _generation++;
    _lastUpdatedGenerations.clear();
    state = PresenceState(generation: _generation);
  }

  Map<String, UserPresenceStatus> _boundedStatuses(
    Map<String, UserPresenceStatus> statuses, {
    String? touchedUserId,
  }) {
    if (touchedUserId != null) {
      _lastUpdatedGenerations[touchedUserId] = _generation;
    }
    _lastUpdatedGenerations.removeWhere((id, _) => !statuses.containsKey(id));
    for (final id in statuses.keys) {
      _lastUpdatedGenerations.putIfAbsent(id, () => _generation);
    }
    if (statuses.length <= maxPresenceStatuses) return statuses;

    final updated = Map<String, UserPresenceStatus>.of(statuses);
    final offlineIds = updated.entries
        .where((entry) => entry.value == UserPresenceStatus.offline)
        .map((entry) => entry.key)
        .toList()
      ..sort(
        (left, right) => (_lastUpdatedGenerations[left] ?? 0)
            .compareTo(_lastUpdatedGenerations[right] ?? 0),
      );

    for (final id in offlineIds) {
      if (updated.length <= maxPresenceStatuses) break;
      updated.remove(id);
      _lastUpdatedGenerations.remove(id);
    }

    if (updated.length > maxPresenceStatuses) {
      final ids = updated.keys.toList()
        ..sort(
          (left, right) => (_lastUpdatedGenerations[left] ?? 0)
              .compareTo(_lastUpdatedGenerations[right] ?? 0),
        );
      for (final id in ids) {
        if (updated.length <= maxPresenceStatuses) break;
        updated.remove(id);
        _lastUpdatedGenerations.remove(id);
      }
    }

    return updated;
  }

  static UserPresenceStatus _parsePresenceLabel(String? label) {
    return switch (label) {
      'online' => UserPresenceStatus.online,
      'idle' => UserPresenceStatus.idle,
      _ => UserPresenceStatus.offline,
    };
  }
}
