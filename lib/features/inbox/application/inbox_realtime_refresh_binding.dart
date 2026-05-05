import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

/// Minimum debounce interval between inbox refreshes triggered
/// by realtime events.
const _refreshDebounceMs = 2000;

/// Binds inbox refresh to realtime events and app lifecycle.
///
/// Triggers:
/// 1. Socket `message:new` or `dm:new` events → debounced refresh
/// 2. Socket `connect` event → immediate refresh
/// 3. App resume (lifecycle resumed) → refresh if inbox was loaded
///
/// Only triggers when InboxStore is in success state (loaded).
final inboxRealtimeRefreshBindingProvider = Provider<void>((ref) {
  final ingress = ref.watch(realtimeReductionIngressProvider);
  Timer? debounceTimer;

  void scheduleRefresh() {
    final inboxState = ref.read(inboxStoreProvider);
    if (inboxState.status != InboxStatus.success) return;

    debounceTimer?.cancel();
    debounceTimer = Timer(
      const Duration(milliseconds: _refreshDebounceMs),
      () {
        ref.read(inboxStoreProvider.notifier).refresh();
      },
    );
  }

  void immediateRefresh() {
    final inboxState = ref.read(inboxStoreProvider);
    if (inboxState.status != InboxStatus.success) return;

    debounceTimer?.cancel();
    ref.read(inboxStoreProvider.notifier).refresh();
  }

  final subscription = ingress.acceptedEvents.listen((event) {
    if (event.eventType == 'message:new' || event.eventType == 'dm:new') {
      scheduleRefresh();
    } else if (event.eventType == 'connect') {
      immediateRefresh();
    }
  });

  // App lifecycle: refresh on resume if inbox is loaded.
  ref.listen(
    notificationStoreProvider.select((s) => s.lifecycleStatus),
    (previous, next) {
      if (next == AppLifecycleStatus.resumed &&
          previous != AppLifecycleStatus.resumed) {
        immediateRefresh();
      }
    },
  );

  ref.onDispose(() {
    debounceTimer?.cancel();
    unawaited(subscription.cancel());
  });
});
