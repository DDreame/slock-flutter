import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

// ---------------------------------------------------------------------------
// #861: Last Active Timestamp — tracks when the user was last active
//
// Written on AppLifecycleState.paused/detached, read on resumed.
// Used by the Summary Card to determine "away duration".
// ---------------------------------------------------------------------------

const _kLastActiveTimestampKey = 'last_active_ts';

/// Provides the timestamp of the user's last active session.
///
/// Returns null on first install (no stored value).
/// Reads synchronously from SharedPreferences (preloaded at startup).
final lastActiveTimestampProvider =
    NotifierProvider<LastActiveTimestampNotifier, DateTime?>(
  LastActiveTimestampNotifier.new,
);

class LastActiveTimestampNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final ms = prefs.getInt(_kLastActiveTimestampKey);

    // Listen for lifecycle changes to write on paused/detached.
    ref.listen<AppLifecycleStatus>(
      notificationStoreProvider.select((s) => s.lifecycleStatus),
      (previous, next) {
        if (next == AppLifecycleStatus.paused ||
            next == AppLifecycleStatus.detached) {
          _writeNow();
        }
      },
    );

    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Writes the current time as the last active timestamp.
  void _writeNow() {
    final now = DateTime.now();
    state = now;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setInt(_kLastActiveTimestampKey, now.millisecondsSinceEpoch);
  }

  /// Marks the user as active right now. Called on app start/resume
  /// to establish the "current session start" so the NEXT pause captures
  /// the correct last-active time.
  void markActive() {
    _writeNow();
  }
}
