import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// #578: Typing Indicator in List Rows — Seam (Phase A)
//
// Per-channel typing indicator store for list rows.
// Phase B implements the real family store + global WebSocket listener.
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
}

/// Family provider keyed by scope key (e.g. "server:s1/channel:ch1").
/// Each list row watches its own instance.
///
/// Phase B implements the real store with:
/// - Global WebSocket listener for `typing:start` events
/// - Per-channel timer-based expiry (5s)
/// - Combined text for multiple typers
final listTypingIndicatorStoreProvider = NotifierProvider.autoDispose
    .family<ListTypingIndicatorNotifier, ListTypingIndicatorState, String>(
  ListTypingIndicatorNotifier.new,
);

class ListTypingIndicatorNotifier
    extends AutoDisposeFamilyNotifier<ListTypingIndicatorState, String> {
  @override
  ListTypingIndicatorState build(String arg) {
    // Phase B: subscribe to global typing event stream filtered by scopeKey.
    throw UnimplementedError(
      'ListTypingIndicatorNotifier not yet implemented',
    );
  }

  /// Add or refresh a remote user's typing indicator.
  /// Auto-clears after 5 seconds if no new event arrives.
  void addTyper({
    required String userId,
    required String displayName,
  }) {
    // Phase B: manage per-user timers and combine display text.
    throw UnimplementedError('addTyper not yet implemented');
  }

  /// Remove a specific user's typing indicator.
  void removeTyper(String userId) {
    // Phase B: cancel timer, rebuild display text.
    throw UnimplementedError('removeTyper not yet implemented');
  }
}
