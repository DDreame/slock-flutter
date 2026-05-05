import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/background_notification_entrypoint.dart';
import 'package:slock_app/core/network/auth_token_provider.dart'
    show selectedServerIdProvider;
import 'package:slock_app/core/realtime/providers.dart'
    show realtimeSocketOptionsProvider;
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Persists auth credentials to SharedPreferences whenever the
/// session changes, so the background notification worker (running
/// in a separate Dart isolate) can read them on startup or refresh.
///
/// On logout, clears the persisted credentials.
final backgroundWorkerAuthBindingProvider = Provider<void>((ref) {
  final diagnostics = ref.read(diagnosticsCollectorProvider);

  ref.listen(sessionStoreProvider, (previous, next) async {
    try {
      if (next.isAuthenticated &&
          next.token != null &&
          next.token!.isNotEmpty) {
        final options = ref.read(realtimeSocketOptionsProvider);
        final serverId = ref.read(selectedServerIdProvider) ?? '';
        await BackgroundWorkerAuthPersistence.persist(
          token: next.token!,
          userId: next.userId ?? '',
          serverId: serverId,
          realtimeUrl: options.uri,
        );
        diagnostics.info(
          'background-worker-auth',
          'Persisted credentials for background worker',
        );
      } else if (next.isUnauthenticated) {
        await BackgroundWorkerAuthPersistence.clear();
        diagnostics.info(
          'background-worker-auth',
          'Cleared background worker credentials',
        );
      }
    } catch (e) {
      diagnostics.error(
        'background-worker-auth',
        'Failed to persist/clear credentials: $e',
      );
    }
  });
});
