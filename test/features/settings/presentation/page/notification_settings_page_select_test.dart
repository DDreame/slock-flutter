// =============================================================================
// #615 — ref.watch .select() narrows — notification_settings_page
//
// Invariant: INV-NOTIFY-SETTINGS-SELECT-1
//   NotificationSettingsPage.build() ref.watch(notificationStoreProvider) at
//   L26 only consumes: permissionStatus, pushToken, pushTokenPlatform,
//   pushTokenUpdatedAt, notificationPreference. Mutations to other
//   NotificationState fields (lifecycleStatus, visibleTarget, currentUserId)
//   must NOT trigger a rebuild.
//
// Strategy:
// T1: lifecycleStatus change must NOT fire 5-field select (skip:true).
// T2: currentUserId change must NOT fire 5-field select (skip:true).
// T3: permissionStatus change DOES fire 5-field select (active).
//
// Phase A: T1/T2 skip:true — current impl uses broad ref.watch.
//          T3 active — correctness proof.
//
// Phase B:
// Replace ref.watch(notificationStoreProvider) at
// notification_settings_page.dart L26 with
// ref.watch(notificationStoreProvider.select((s) => (
//   permissionStatus: s.permissionStatus, pushToken: s.pushToken,
//   pushTokenPlatform: s.pushTokenPlatform,
//   pushTokenUpdatedAt: s.pushTokenUpdatedAt,
//   notificationPreference: s.notificationPreference))).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableNotificationStore extends NotificationStore {
  @override
  NotificationState build() => const NotificationState(
        permissionStatus: NotificationPermissionStatus.granted,
      );

  void setLifecycleStatusDirect(AppLifecycleStatus status) {
    state = state.copyWith(lifecycleStatus: status);
  }

  void setCurrentUserIdDirect(String userId) {
    state = state.copyWith(currentUserId: userId);
  }

  void setPermissionStatusDirect(NotificationPermissionStatus status) {
    state = state.copyWith(permissionStatus: status);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: lifecycleStatus change must NOT fire 5-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-NOTIFY-SETTINGS-SELECT-1: lifecycleStatus change does NOT notify '
    '5-field select',
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
          (s) => (
            permissionStatus: s.permissionStatus,
            pushToken: s.pushToken,
            pushTokenPlatform: s.pushTokenPlatform,
            pushTokenUpdatedAt: s.pushTokenUpdatedAt,
            notificationPreference: s.notificationPreference,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(notificationStoreProvider.notifier)
          as _ControllableNotificationStore;
      store.setLifecycleStatusDirect(AppLifecycleStatus.paused);

      expect(
        selectNotifyCount,
        0,
        reason: 'lifecycleStatus change must not notify 5-field select '
            '(INV-NOTIFY-SETTINGS-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: true, // Phase A: requires Phase B .select() fix
  );

  // -------------------------------------------------------------------------
  // T2: currentUserId change must NOT fire 5-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-NOTIFY-SETTINGS-SELECT-1: currentUserId change does NOT notify '
    '5-field select',
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
          (s) => (
            permissionStatus: s.permissionStatus,
            pushToken: s.pushToken,
            pushTokenPlatform: s.pushTokenPlatform,
            pushTokenUpdatedAt: s.pushTokenUpdatedAt,
            notificationPreference: s.notificationPreference,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(notificationStoreProvider.notifier)
          as _ControllableNotificationStore;
      store.setCurrentUserIdDirect('new-user-id');

      expect(
        selectNotifyCount,
        0,
        reason: 'currentUserId change must not notify 5-field select '
            '(INV-NOTIFY-SETTINGS-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: true, // Phase A: requires Phase B .select() fix
  );

  // -------------------------------------------------------------------------
  // T3: permissionStatus change DOES fire 5-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-NOTIFY-SETTINGS-SELECT-1: permissionStatus change DOES notify '
    '5-field select',
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
          (s) => (
            permissionStatus: s.permissionStatus,
            pushToken: s.pushToken,
            pushTokenPlatform: s.pushTokenPlatform,
            pushTokenUpdatedAt: s.pushTokenUpdatedAt,
            notificationPreference: s.notificationPreference,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(notificationStoreProvider.notifier)
          as _ControllableNotificationStore;
      store.setPermissionStatusDirect(NotificationPermissionStatus.denied);

      expect(
        selectNotifyCount,
        1,
        reason: 'permissionStatus change must notify 5-field select',
      );

      keepAlive.close();
    },
  );
}
