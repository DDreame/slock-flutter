import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/realtime/realtime_connection_state.dart';
import 'package:slock_app/core/realtime/providers.dart'
    show realtimeServiceProvider;
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

/// Debounce duration for refresh triggers. Prevents stampeding
/// when multiple signals (resume + reconnect) fire simultaneously
/// or in rapid succession.
const homeRefreshDebounceDuration = Duration(milliseconds: 500);

/// Provides the app lifecycle status that the refresh binding
/// watches. Override in tests to simulate lifecycle transitions.
final homeRefreshLifecycleStatusProvider = Provider<AppLifecycleStatus>((ref) {
  return ref.watch(
    notificationStoreProvider.select((s) => s.lifecycleStatus),
  );
});

/// Provides the realtime connection state that the refresh binding
/// watches. Override in tests to simulate reconnection.
final homeRefreshRealtimeStateProvider =
    Provider<RealtimeConnectionState>((ref) {
  return ref.watch(realtimeServiceProvider);
});

/// Triggers [HomeListStore.load()] on:
/// - App lifecycle resuming (→ resumed)
/// - WebSocket reconnection (reconnecting → connected)
///
/// Both signals are debounced through a shared timer so
/// simultaneous events result in a single load() call.
/// When Home is not yet in success state, load() is still
/// triggered — its completion will transition status to success,
/// which drains the pending-event queue in the realtime binding.
final homeRefreshLifecycleBindingProvider = Provider<void>((ref) {
  Timer? debounceTimer;

  void scheduleRefresh() {
    debounceTimer?.cancel();
    debounceTimer = Timer(homeRefreshDebounceDuration, () {
      ref.read(homeListStoreProvider.notifier).load();
    });
  }

  // Listen for lifecycle transitions TO resumed.
  ref.listen<AppLifecycleStatus>(
    homeRefreshLifecycleStatusProvider,
    (previous, next) {
      if (next == AppLifecycleStatus.resumed &&
          previous != null &&
          previous != AppLifecycleStatus.resumed) {
        scheduleRefresh();
      }
    },
  );

  // Listen for realtime reconnection.
  ref.listen<RealtimeConnectionState>(
    homeRefreshRealtimeStateProvider,
    (previous, next) {
      if (previous == null) return;
      if (previous.status == RealtimeConnectionStatus.reconnecting &&
          next.status == RealtimeConnectionStatus.connected) {
        scheduleRefresh();
      }
    },
  );

  ref.onDispose(() {
    debounceTimer?.cancel();
  });
});
