import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Default timeout after which a remote user's typing indicator expires
/// if no new typing event is received.
const kTypingIndicatorExpiry = Duration(seconds: 5);

/// Default cooldown between typing event emissions to the server.
const kTypingEmitCooldown = Duration(seconds: 3);

/// A single active typer.
@immutable
class ActiveTyper {
  const ActiveTyper({
    required this.userId,
    required this.displayName,
  });

  final String userId;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveTyper &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          displayName == other.displayName;

  @override
  int get hashCode => Object.hash(userId, displayName);
}

/// Immutable state holding the set of users currently typing.
@immutable
class TypingIndicatorState {
  const TypingIndicatorState({
    this.activeTypers = const [],
  });

  /// Ordered list of users currently typing (insertion order).
  final List<ActiveTyper> activeTypers;

  TypingIndicatorState copyWith({List<ActiveTyper>? activeTypers}) {
    return TypingIndicatorState(
      activeTypers: activeTypers ?? this.activeTypers,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypingIndicatorState &&
          runtimeType == other.runtimeType &&
          listEquals(activeTypers, other.activeTypers);

  @override
  int get hashCode => Object.hashAll(activeTypers);
}

final typingIndicatorStoreProvider =
    NotifierProvider.autoDispose<TypingIndicatorStore, TypingIndicatorState>(
  TypingIndicatorStore.new,
);

class TypingIndicatorStore extends AutoDisposeNotifier<TypingIndicatorState> {
  final Map<String, Timer> _expiryTimers = {};
  DateTime? _lastEmitTime;

  /// Guard: set true in onDispose to prevent timer callbacks from
  /// mutating state on a stale/disposed notifier (#723).
  bool _disposed = false;

  @override
  bool updateShouldNotify(
    TypingIndicatorState previous,
    TypingIndicatorState next,
  ) =>
      previous != next;

  @override
  TypingIndicatorState build() {
    ref.onDispose(() {
      _disposed = true;
      for (final timer in _expiryTimers.values) {
        timer.cancel();
      }
      _expiryTimers.clear();
    });

    return const TypingIndicatorState();
  }

  /// Add or refresh a remote user's typing indicator.
  ///
  /// If [userId] is already active, the expiry timer is reset.
  /// [expiry] defaults to [kTypingIndicatorExpiry].
  void addTyper({
    required String userId,
    required String displayName,
    Duration expiry = kTypingIndicatorExpiry,
  }) {
    if (_disposed) return;

    // Cancel existing timer for this user.
    _expiryTimers[userId]?.cancel();

    // Schedule auto-removal.
    _expiryTimers[userId] = Timer(expiry, () {
      if (_disposed) return;
      removeTyper(userId);
    });

    // Update state: replace or append.
    final existing = state.activeTypers;
    final updated = existing.where((t) => t.userId != userId).toList()
      ..add(ActiveTyper(userId: userId, displayName: displayName));

    state = state.copyWith(activeTypers: updated);
  }

  /// Remove a user's typing indicator.
  void removeTyper(String userId) {
    if (_disposed) return;

    _expiryTimers[userId]?.cancel();
    _expiryTimers.remove(userId);

    final updated =
        state.activeTypers.where((t) => t.userId != userId).toList();
    if (updated.length != state.activeTypers.length) {
      state = state.copyWith(activeTypers: updated);
    }
  }

  /// Remove all typing indicators and cancel all timers.
  void clearAll() {
    for (final timer in _expiryTimers.values) {
      timer.cancel();
    }
    _expiryTimers.clear();
    if (!_disposed) {
      state = const TypingIndicatorState();
    }
  }

  /// Returns `true` if a typing event should be emitted to the server
  /// (i.e. the cooldown has expired since the last emit).
  ///
  /// When `true`, the internal timestamp is updated so subsequent calls
  /// return `false` until [cooldown] elapses.
  bool shouldEmitTyping({Duration cooldown = kTypingEmitCooldown}) {
    final now = DateTime.now();
    if (_lastEmitTime != null && now.difference(_lastEmitTime!) < cooldown) {
      return false;
    }
    _lastEmitTime = now;
    return true;
  }
}
