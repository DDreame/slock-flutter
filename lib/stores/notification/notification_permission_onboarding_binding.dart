import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Triggers notification permission onboarding when the session
/// transitions to authenticated (login/register).
///
/// This complements the splash-path onboarding: the splash controller
/// calls [NotificationStore.onboardPermissionIfNeeded] for sessions
/// restored from storage, while this binding covers fresh login/register
/// flows that start unauthenticated.
///
/// [NotificationStore.onboardPermissionIfNeeded] is safe to call
/// repeatedly — it only prompts when permission status is [unknown].
final notificationPermissionOnboardingBindingProvider = Provider<void>((ref) {
  ref.listen<SessionState>(
    sessionStoreProvider,
    (previous, next) {
      if (previous == null) return;

      if (!previous.isAuthenticated && next.isAuthenticated) {
        final notifStore = ref.read(notificationStoreProvider.notifier);
        unawaited(
          notifStore.onboardPermissionIfNeeded().catchError((_) {}),
        );
      }
    },
  );
});
