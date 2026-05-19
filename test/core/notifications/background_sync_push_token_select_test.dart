// =============================================================================
// #626 — Background sync + push token lifecycle binding .select() narrows
//
// Invariant: INV-BACKGROUND-SYNC-SELECT-1
//   background_sync_lifecycle_binding.dart:
//   L89: ref.listen<SessionState>(sessionStoreProvider, ...) — only needs
//     status (isAuthenticated / isUnauthenticated derive from it).
//     displayName, avatarUrl, userId, emailVerified must NOT fire.
//   L97: ref.listen<NotificationState>(notificationStoreProvider, ...) — only
//     needs lifecycleStatus. pushToken, visibleTarget, permissionStatus, etc.
//     must NOT fire.
//   L101: ref.listen<ServerSelectionState>(serverSelectionStoreProvider, ...) —
//     only needs selectedServerId (single-field state, documents intent).
//
// Invariant: INV-PUSH-TOKEN-BINDING-SELECT-1
//   push_token_lifecycle_binding.dart L15:
//   ref.listen<NotificationState>(notificationStoreProvider, ...) — only
//   consumes pushToken + pushTokenPlatform. Mutations to lifecycleStatus,
//   visibleTarget, permissionStatus, notificationPreference, currentUserId
//   MUST NOT fire.
//
// Strategy:
// T1: displayName change must NOT fire session status select (skip:true).
// T2: status change DOES fire session status select (active).
// T3: visibleTarget change must NOT fire lifecycleStatus select (skip:true).
// T4: lifecycleStatus change DOES fire lifecycleStatus select (active).
// T5: permissionStatus change must NOT fire (pushToken, pushTokenPlatform)
//     select (skip:true).
// T6: pushToken change DOES fire (pushToken, pushTokenPlatform) select
//     (active).
//
// Phase A: T1/T3/T5 skip:true — current impl listens to full state.
//          T2/T4/T6 active — correctness proof.
//
// Phase B:
// - background_sync_lifecycle_binding.dart L89:
//     sessionStoreProvider.select((s) => s.status)
// - background_sync_lifecycle_binding.dart L97:
//     notificationStoreProvider.select((s) => s.lifecycleStatus)
// - background_sync_lifecycle_binding.dart L101:
//     serverSelectionStoreProvider.select((s) => s.selectedServerId)
// - push_token_lifecycle_binding.dart L15:
//     notificationStoreProvider.select(
//       (s) => (pushToken: s.pushToken, pushTokenPlatform: s.pushTokenPlatform))
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        token: 'test-token',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.png',
        userId: 'user-1',
        emailVerified: true,
      );

  void setDisplayNameDirect(String name) {
    state = state.copyWith(displayName: name);
  }

  void setStatusDirect(AuthStatus status) {
    state = state.copyWith(status: status);
  }
}

class _ControllableNotificationStore extends NotificationStore {
  @override
  NotificationState build() => const NotificationState(
        lifecycleStatus: AppLifecycleStatus.resumed,
        pushToken: 'token-123',
        pushTokenPlatform: 'android',
        permissionStatus: NotificationPermissionStatus.granted,
      );

  void setVisibleTargetDirect(VisibleTarget? target) {
    state = state.copyWith(visibleTarget: target);
  }

  void setLifecycleStatusDirect(AppLifecycleStatus status) {
    state = state.copyWith(lifecycleStatus: status);
  }

  void setPermissionStatusDirect(NotificationPermissionStatus status) {
    state = state.copyWith(permissionStatus: status);
  }

  void setPushTokenDirect(String token) {
    state = state.copyWith(pushToken: token);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Background sync — INV-BACKGROUND-SYNC-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T1: displayName change must NOT fire session status select.
  // -------------------------------------------------------------------------
  test(
    'INV-BACKGROUND-SYNC-SELECT-1: displayName change does NOT notify '
    'status select',
    skip: true,
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _ControllableSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(sessionStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        sessionStoreProvider.select((s) => s.status),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setDisplayNameDirect('New Name');

      expect(
        selectNotifyCount,
        0,
        reason: 'displayName change must not notify status select '
            '(INV-BACKGROUND-SYNC-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: status change DOES fire session status select.
  // -------------------------------------------------------------------------
  test(
    'INV-BACKGROUND-SYNC-SELECT-1: status change DOES notify '
    'status select',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _ControllableSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(sessionStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        sessionStoreProvider.select((s) => s.status),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setStatusDirect(AuthStatus.unauthenticated);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify status select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: visibleTarget change must NOT fire lifecycleStatus select.
  // -------------------------------------------------------------------------
  test(
    'INV-BACKGROUND-SYNC-SELECT-1: visibleTarget change does NOT notify '
    'lifecycleStatus select',
    skip: true,
    () async {
      final container = ProviderContainer(
        overrides: [
          notificationStoreProvider
              .overrideWith(() => _ControllableNotificationStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(notificationStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        notificationStoreProvider.select((s) => s.lifecycleStatus),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(notificationStoreProvider.notifier)
          as _ControllableNotificationStore;
      store.setVisibleTargetDirect(
        const VisibleTarget(
          serverId: 'srv-1',
          surface: NotificationSurface.channel,
          channelId: 'ch-1',
        ),
      );

      expect(
        selectNotifyCount,
        0,
        reason: 'visibleTarget change must not notify lifecycleStatus select '
            '(INV-BACKGROUND-SYNC-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: lifecycleStatus change DOES fire lifecycleStatus select.
  // -------------------------------------------------------------------------
  test(
    'INV-BACKGROUND-SYNC-SELECT-1: lifecycleStatus change DOES notify '
    'lifecycleStatus select',
    () async {
      final container = ProviderContainer(
        overrides: [
          notificationStoreProvider
              .overrideWith(() => _ControllableNotificationStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(notificationStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        notificationStoreProvider.select((s) => s.lifecycleStatus),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(notificationStoreProvider.notifier)
          as _ControllableNotificationStore;
      store.setLifecycleStatusDirect(AppLifecycleStatus.paused);

      expect(
        selectNotifyCount,
        1,
        reason: 'lifecycleStatus change must notify lifecycleStatus select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // Push token binding — INV-PUSH-TOKEN-BINDING-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T5: permissionStatus change must NOT fire (pushToken, platform) select.
  // -------------------------------------------------------------------------
  test(
    'INV-PUSH-TOKEN-BINDING-SELECT-1: permissionStatus change does NOT notify '
    '(pushToken, pushTokenPlatform) select',
    skip: true,
    () async {
      final container = ProviderContainer(
        overrides: [
          notificationStoreProvider
              .overrideWith(() => _ControllableNotificationStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(notificationStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        notificationStoreProvider.select(
          (s) => (pushToken: s.pushToken, platform: s.pushTokenPlatform),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(notificationStoreProvider.notifier)
          as _ControllableNotificationStore;
      store.setPermissionStatusDirect(NotificationPermissionStatus.denied);

      expect(
        selectNotifyCount,
        0,
        reason: 'permissionStatus change must not notify '
            '(pushToken, pushTokenPlatform) select '
            '(INV-PUSH-TOKEN-BINDING-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T6: pushToken change DOES fire (pushToken, platform) select.
  // -------------------------------------------------------------------------
  test(
    'INV-PUSH-TOKEN-BINDING-SELECT-1: pushToken change DOES notify '
    '(pushToken, pushTokenPlatform) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          notificationStoreProvider
              .overrideWith(() => _ControllableNotificationStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(notificationStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        notificationStoreProvider.select(
          (s) => (pushToken: s.pushToken, platform: s.pushTokenPlatform),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(notificationStoreProvider.notifier)
          as _ControllableNotificationStore;
      store.setPushTokenDirect('new-token-456');

      expect(
        selectNotifyCount,
        1,
        reason: 'pushToken change must notify '
            '(pushToken, pushTokenPlatform) select',
      );

      keepAlive.close();
    },
  );
}
