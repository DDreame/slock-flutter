import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/servers/data/unread_summary_repository_provider.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Poll interval for unread summary (matching web: 30 seconds).
@visibleForTesting
const unreadSummaryPollInterval = Duration(seconds: 30);

/// State: a map from serverId → unreadCount.
/// Empty map = no unread messages (or not yet loaded / logged out).
typedef UnreadSummaryState = Map<String, int>;

final unreadSummaryStoreProvider =
    NotifierProvider<UnreadSummaryStore, UnreadSummaryState>(
        UnreadSummaryStore.new);

class UnreadSummaryStore extends Notifier<UnreadSummaryState> {
  Timer? _pollTimer;

  @override
  UnreadSummaryState build() {
    // Gate on authentication — clear and stop polling on logout.
    final isAuthenticated = ref.watch(
      sessionStoreProvider.select((s) => s.isAuthenticated),
    );

    if (!isAuthenticated) {
      _stopPolling();
      return const {};
    }

    // Start polling.
    _startPolling();

    // Initial fetch.
    Future.microtask(_fetch);

    ref.onDispose(_stopPolling);

    return const {};
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(unreadSummaryPollInterval, (_) => _fetch());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Public method to trigger a refresh (e.g. on app resume).
  /// No-op when unauthenticated.
  void refresh() => _fetch();

  Future<void> _fetch() async {
    // Guard: do not fetch if unauthenticated (e.g. resume after logout,
    // or in-flight fetch completes after auth state changed).
    if (!ref.read(sessionStoreProvider).isAuthenticated) return;

    try {
      final entries =
          await ref.read(unreadSummaryRepositoryProvider).loadUnreadSummary();

      // Re-check auth after async gap — session may have changed.
      if (!ref.read(sessionStoreProvider).isAuthenticated) return;

      final map = <String, int>{};
      for (final entry in entries) {
        map[entry.serverId] = entry.unreadCount;
      }
      state = map;
    } catch (_) {
      // Silently ignore fetch errors — stale data is acceptable for a
      // best-effort badge. The next poll cycle will retry.
    }
  }
}

/// Lifecycle binding that triggers [UnreadSummaryStore.refresh()] on app resume.
///
/// Mirrors the pattern from [realtimeLifecycleBindingProvider]: a
/// [WidgetsBindingObserver] that fires on [AppLifecycleState.resumed].
final unreadSummaryLifecycleBindingProvider = Provider<void>((ref) {
  final observer = _UnreadSummaryLifecycleObserver(
    onResumed: () {
      ref.read(unreadSummaryStoreProvider.notifier).refresh();
    },
  );
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
});

class _UnreadSummaryLifecycleObserver extends WidgetsBindingObserver {
  _UnreadSummaryLifecycleObserver({required this.onResumed});

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
