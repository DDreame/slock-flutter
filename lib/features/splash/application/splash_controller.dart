import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

final splashControllerProvider =
    AutoDisposeAsyncNotifierProvider<SplashController, void>(
  SplashController.new,
);

class SplashController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {
    try {
      final session = ref.read(sessionStoreProvider);
      if (session.status == AuthStatus.unknown) {
        await ref.read(sessionStoreProvider.notifier).restoreSession();
      }
      final updatedSession = ref.read(sessionStoreProvider);
      if (updatedSession.isAuthenticated) {
        // Yield so provider state changes below run outside synchronous init.
        await Future<void>.value();
        await Future.wait([
          ref.read(serverSelectionStoreProvider.notifier).restoreSelection(),
          ref.read(serverListStoreProvider.notifier).load(),
        ]);
      }
      final notificationStore = ref.read(notificationStoreProvider.notifier);
      final diagnostics = ref.read(diagnosticsCollectorProvider);
      unawaited(
        notificationStore.init().catchError((Object e) {
          diagnostics.add(DiagnosticsEntry(
            timestamp: DateTime.now(),
            level: DiagnosticsLevel.error,
            tag: 'splash',
            message: 'Deferred notification init failed: $e',
          ));
        }),
      );
    } finally {
      ref.read(appReadyProvider.notifier).state = true;
    }
  }
}
