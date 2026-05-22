import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/push_token/data/push_token_repository.dart';
import 'package:slock_app/features/push_token/data/push_token_repository_provider.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

final pushTokenLifecycleBindingProvider = Provider<void>((ref) {
  final repo = ref.watch(pushTokenRepositoryProvider);
  final crashReporter = ref.read(crashReporterProvider);
  final diagnostics = ref.read(diagnosticsCollectorProvider);

  // INV-PUSH-TOKEN-BINDING-SELECT-1: Only consume pushToken +
  // pushTokenPlatform. Mutations to lifecycleStatus, visibleTarget,
  // permissionStatus, etc. must NOT fire.
  ref.listen(
    notificationStoreProvider.select(
      (s) => (pushToken: s.pushToken, pushTokenPlatform: s.pushTokenPlatform),
    ),
    (previous, next) {
      if (previous == null) return;
      final oldToken = previous.pushToken;
      final newToken = next.pushToken;
      final platformChanged =
          previous.pushTokenPlatform != next.pushTokenPlatform;

      if (oldToken == newToken && !platformChanged) return;

      final session = ref.read(sessionStoreProvider);
      if (!session.isAuthenticated) return;

      if (oldToken != null && newToken != null && oldToken != newToken) {
        unawaited(_deregisterThenRegister(repo, oldToken, newToken,
            platform: next.pushTokenPlatform,
            crashReporter: crashReporter,
            diagnostics: diagnostics));
      } else if (oldToken == null && newToken != null) {
        unawaited(_register(repo, newToken,
            platform: next.pushTokenPlatform,
            crashReporter: crashReporter,
            diagnostics: diagnostics));
      } else if (oldToken == newToken && newToken != null && platformChanged) {
        unawaited(_register(repo, newToken,
            platform: next.pushTokenPlatform,
            crashReporter: crashReporter,
            diagnostics: diagnostics));
      }
    },
  );

  ref.listen(
    sessionStoreProvider.select(
      (s) => (isAuthenticated: s.isAuthenticated, token: s.token),
    ),
    (previous, next) {
      if (previous == null) return;

      if (!previous.isAuthenticated && next.isAuthenticated) {
        final notifState = ref.read(notificationStoreProvider);
        final token = notifState.pushToken;
        if (token != null) {
          unawaited(_register(repo, token,
              platform: notifState.pushTokenPlatform,
              crashReporter: crashReporter,
              diagnostics: diagnostics));
        }
        return;
      }

      if (previous.isAuthenticated && !next.isAuthenticated) {
        final notifState = ref.read(notificationStoreProvider);
        final token = notifState.pushToken;
        if (token != null) {
          unawaited(_deregisterWithAuth(repo, token, previous.token,
              crashReporter: crashReporter));
        }
      }
    },
  );
});

Future<void> _register(
  PushTokenRepository repo,
  String token, {
  String? platform,
  required CrashReporter crashReporter,
  DiagnosticsCollector? diagnostics,
}) async {
  try {
    await repo.registerToken(
      token: token,
      platform: platform ?? 'unknown',
    );
  } on StateError catch (_) {
  } catch (e, s) {
    crashReporter.captureException(e, stackTrace: s);
    // Surface registration failure to settings diagnostics so the user
    // knows push notifications may not be delivered (#720).
    diagnostics?.add(DiagnosticsEntry(
      timestamp: DateTime.now(),
      level: DiagnosticsLevel.error,
      tag: 'push_token',
      message: 'Push token registration failed: $e',
    ));
  }
}

/// Timeout for deregister calls to prevent indefinite hangs (#716).
@visibleForTesting
const deregisterTimeout = Duration(seconds: 10);

/// Deregister old token (with timeout), then register new token.
///
/// Exposed for testing; production code calls this internally.
@visibleForTesting
Future<void> deregisterThenRegisterForTest(
  PushTokenRepository repo,
  String oldToken,
  String newToken, {
  String? platform,
  required CrashReporter crashReporter,
  DiagnosticsCollector? diagnostics,
}) =>
    _deregisterThenRegister(repo, oldToken, newToken,
        platform: platform,
        crashReporter: crashReporter,
        diagnostics: diagnostics);

Future<void> _deregisterThenRegister(
  PushTokenRepository repo,
  String oldToken,
  String newToken, {
  String? platform,
  required CrashReporter crashReporter,
  DiagnosticsCollector? diagnostics,
}) async {
  try {
    await repo.deregisterToken(token: oldToken).timeout(deregisterTimeout);
  } on StateError catch (_) {
  } on TimeoutException catch (_) {
    // Deregister hung — proceed with registration anyway (#716).
  } catch (e, s) {
    crashReporter.captureException(e, stackTrace: s);
  }
  await _register(repo, newToken,
      platform: platform,
      crashReporter: crashReporter,
      diagnostics: diagnostics);
}

Future<void> _deregisterWithAuth(
  PushTokenRepository repo,
  String token,
  String? authToken, {
  required CrashReporter crashReporter,
}) async {
  try {
    await repo.deregisterToken(token: token, authToken: authToken);
  } on StateError catch (_) {
  } catch (e, s) {
    crashReporter.captureException(e, stackTrace: s);
  }
}
