import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/push_token/data/push_token_repository.dart';
import 'package:slock_app/features/push_token/data/push_token_repository_provider.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

final pushTokenLifecycleBindingProvider = Provider<void>((ref) {
  final repo = ref.watch(pushTokenRepositoryProvider);

  ref.listen<NotificationState>(
    notificationStoreProvider,
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
            platform: next.pushTokenPlatform));
      } else if (oldToken == null && newToken != null) {
        unawaited(_register(repo, newToken, platform: next.pushTokenPlatform));
      } else if (oldToken == newToken && newToken != null && platformChanged) {
        unawaited(_register(repo, newToken, platform: next.pushTokenPlatform));
      }
    },
  );

  ref.listen<SessionState>(
    sessionStoreProvider,
    (previous, next) {
      if (previous == null) return;

      if (!previous.isAuthenticated && next.isAuthenticated) {
        final notifState = ref.read(notificationStoreProvider);
        final token = notifState.pushToken;
        if (token != null) {
          unawaited(
              _register(repo, token, platform: notifState.pushTokenPlatform));
        }
        return;
      }

      if (previous.isAuthenticated && !next.isAuthenticated) {
        final notifState = ref.read(notificationStoreProvider);
        final token = notifState.pushToken;
        if (token != null) {
          unawaited(_deregisterWithAuth(repo, token, previous.token));
        }
      }
    },
  );
});

Future<void> _register(
  PushTokenRepository repo,
  String token, {
  String? platform,
}) async {
  try {
    await repo.registerToken(
      token: token,
      platform: platform ?? 'unknown',
    );
  } catch (_) {}
}

Future<void> _deregisterThenRegister(
  PushTokenRepository repo,
  String oldToken,
  String newToken, {
  String? platform,
}) async {
  try {
    await repo.deregisterToken(token: oldToken);
  } catch (_) {}
  await _register(repo, newToken, platform: platform);
}

Future<void> _deregisterWithAuth(
  PushTokenRepository repo,
  String token,
  String? authToken,
) async {
  try {
    await repo.deregisterToken(token: token, authToken: authToken);
  } catch (_) {}
}
