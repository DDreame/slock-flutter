import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
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
        await ref
            .read(serverSelectionStoreProvider.notifier)
            .restoreSelection();
      }
    } finally {
      ref.read(appReadyProvider.notifier).state = true;
    }
  }
}
