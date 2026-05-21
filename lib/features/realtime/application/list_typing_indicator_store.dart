import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// #578: Typing Indicator in List Rows — Phase B
//
// Per-channel typing indicator store for list rows.
// Family-keyed by scope key (e.g. "server:s1/channel:ch1").
// Manages per-user timers that auto-expire after 5 seconds.
// ---------------------------------------------------------------------------

/// State for a single channel/DM's typing indicator in list rows.
@immutable
class ListTypingIndicatorState {
  const ListTypingIndicatorState({
    this.displayText,
  });

  /// Text to show in the list row (e.g. "Alice is typing...").
  /// Null when nobody is typing in this channel.
  final String? displayText;

  bool get isActive => displayText != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListTypingIndicatorState &&
          runtimeType == other.runtimeType &&
          displayText == other.displayText;

  @override
  int get hashCode => displayText.hashCode;
}

/// Family provider keyed by scope key (e.g. "server:s1/channel:ch1").
/// Each list row watches its own instance.
final listTypingIndicatorStoreProvider = NotifierProvider.autoDispose
    .family<ListTypingIndicatorNotifier, ListTypingIndicatorState, String>(
  ListTypingIndicatorNotifier.new,
);

class ListTypingIndicatorNotifier
    extends AutoDisposeFamilyNotifier<ListTypingIndicatorState, String> {
  /// Active typers: userId → displayName.
  final Map<String, String> _typers = {};

  /// Per-user expiry timers (5-second auto-clear).
  final Map<String, Timer> _timers = {};

  /// Guard: set true in onDispose to prevent timer callbacks from
  /// mutating state on a stale notifier (#716).
  bool _disposed = false;

  @override
  bool updateShouldNotify(
    ListTypingIndicatorState previous,
    ListTypingIndicatorState next,
  ) =>
      previous != next;

  @override
  ListTypingIndicatorState build(String arg) {
    ref.onDispose(() {
      _disposed = true;
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
      _typers.clear();
    });
    return const ListTypingIndicatorState();
  }

  /// Add or refresh a remote user's typing indicator.
  /// Auto-clears after 5 seconds if no new event arrives.
  void addTyper({
    required String userId,
    required String displayName,
  }) {
    if (_disposed) return;

    // Cancel existing timer for this user (refresh).
    _timers[userId]?.cancel();

    _typers[userId] = displayName;

    // Start 5-second expiry timer.
    _timers[userId] = Timer(const Duration(seconds: 5), () {
      if (_disposed) return;
      _typers.remove(userId);
      _timers.remove(userId);
      state = ListTypingIndicatorState(displayText: _buildDisplayText());
    });

    state = ListTypingIndicatorState(displayText: _buildDisplayText());
  }

  /// Remove a specific user's typing indicator.
  void removeTyper(String userId) {
    if (_disposed) return;

    _timers[userId]?.cancel();
    _timers.remove(userId);
    _typers.remove(userId);
    state = ListTypingIndicatorState(displayText: _buildDisplayText());
  }

  /// Builds the combined display text from active typers.
  String? _buildDisplayText() {
    if (_typers.isEmpty) return null;

    final names = _typers.values.toList();
    if (names.length == 1) {
      return '${names[0]} is typing...';
    }
    if (names.length == 2) {
      return '${names[0]} and ${names[1]} are typing...';
    }
    // 3+ typers: "X, Y, and Z are typing..."
    final allButLast = names.sublist(0, names.length - 1).join(', ');
    return '$allButLast, and ${names.last} are typing...';
  }
}
