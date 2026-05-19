// =============================================================================
// #594 — Settings notificationStore Select Optimization
//
// Invariant: INV-SETTINGS-SELECT-1
//   Settings page rebuilds only on consumed notification fields
//   (permissionStatus, notificationPreference).
//
// Strategy:
// T1: Verify that changing `visibleTarget` does NOT notify a per-field select
//     (skip:true — current impl watches full state).
// T2: Verify that changing `lifecycleStatus` does NOT notify a per-field select
//     (skip:true — current impl watches full state).
// T3: Verify that changing `permissionStatus` DOES notify the select.
// T4: Verify that changing `notificationPreference` DOES notify the select.
// T5: Anti-pattern proof — full-state watch fires on visibleTarget change.
//
// Phase A: T1/T2 skip:true — current implementation has no select().
//
// Phase B:
// 1. Replace ref.watch(notificationStoreProvider) with
//    ref.watch(notificationStoreProvider.select(
//      (s) => (permStatus: s.permissionStatus, pref: s.notificationPreference),
//    ))
// 2. Update _notificationSummary() to use the narrowed record.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableNotificationStore extends NotificationStore {
  @override
  NotificationState build() => const NotificationState();

  void setVisibleTargetDirect(VisibleTarget? target) {
    if (target == null) {
      state = state.copyWith(clearVisibleTarget: true);
    } else {
      state = state.copyWith(visibleTarget: target);
    }
  }

  void setLifecycleStatusDirect(AppLifecycleStatus status) {
    state = state.copyWith(lifecycleStatus: status);
  }

  void setPermissionStatusDirect(NotificationPermissionStatus status) {
    state = state.copyWith(permissionStatus: status);
  }

  void setNotificationPreferenceDirect(NotificationPreference pref) {
    state = state.copyWith(notificationPreference: pref);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: Changing visibleTarget must NOT notify per-field select.
  //
  // With the current full-state watch, any mutation (including visibleTarget)
  // causes rebuilds. After Phase B fix (per-field select), only
  // permissionStatus and notificationPreference changes notify.
  //
  // skip:true — requires Phase B per-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-SETTINGS-SELECT-1: visibleTarget change does NOT notify consumed-field '
    'select',
    skip: true,
    () async {
      final container = ProviderContainer(
        overrides: [
          notificationStoreProvider
              .overrideWith(() => _ControllableNotificationStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        notificationStoreProvider,
        (_, __) {},
      );

      // Per-field select (the Phase B pattern).
      int selectNotifyCount = 0;
      container.listen(
        notificationStoreProvider.select(
          (s) => (
            permStatus: s.permissionStatus,
            pref: s.notificationPreference,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate visibleTarget.
      final store = container.read(notificationStoreProvider.notifier)
          as _ControllableNotificationStore;
      store.setVisibleTargetDirect(
        const VisibleTarget(
          serverId: 'server-1',
          surface: NotificationSurface.channel,
          channelId: 'ch-1',
        ),
      );

      // Per-field select must NOT fire.
      expect(
        selectNotifyCount,
        0,
        reason: 'visibleTarget change must not notify per-field select '
            '(INV-SETTINGS-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: Changing lifecycleStatus must NOT notify per-field select.
  //
  // skip:true — requires Phase B per-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-SETTINGS-SELECT-1: lifecycleStatus change does NOT notify '
    'consumed-field select',
    skip: true,
    () async {
      final container = ProviderContainer(
        overrides: [
          notificationStoreProvider
              .overrideWith(() => _ControllableNotificationStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        notificationStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        notificationStoreProvider.select(
          (s) => (
            permStatus: s.permissionStatus,
            pref: s.notificationPreference,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate lifecycleStatus.
      final store = container.read(notificationStoreProvider.notifier)
          as _ControllableNotificationStore;
      store.setLifecycleStatusDirect(AppLifecycleStatus.paused);

      // Per-field select must NOT fire.
      expect(
        selectNotifyCount,
        0,
        reason: 'lifecycleStatus change must not notify per-field select '
            '(INV-SETTINGS-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: Changing permissionStatus DOES notify per-field select.
  //
  // This test passes now and after Phase B (consumed fields always fire).
  // -------------------------------------------------------------------------
  test(
    'INV-SETTINGS-SELECT-1: permissionStatus change DOES notify select',
    () async {
      final container = ProviderContainer(
        overrides: [
          notificationStoreProvider
              .overrideWith(() => _ControllableNotificationStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        notificationStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        notificationStoreProvider.select(
          (s) => (
            permStatus: s.permissionStatus,
            pref: s.notificationPreference,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate permissionStatus.
      final store = container.read(notificationStoreProvider.notifier)
          as _ControllableNotificationStore;
      store.setPermissionStatusDirect(NotificationPermissionStatus.granted);

      expect(
        selectNotifyCount,
        1,
        reason: 'permissionStatus change must notify per-field select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: Changing notificationPreference DOES notify per-field select.
  //
  // This test passes now and after Phase B.
  // -------------------------------------------------------------------------
  test(
    'INV-SETTINGS-SELECT-1: notificationPreference change DOES notify select',
    () async {
      final container = ProviderContainer(
        overrides: [
          notificationStoreProvider
              .overrideWith(() => _ControllableNotificationStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        notificationStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        notificationStoreProvider.select(
          (s) => (
            permStatus: s.permissionStatus,
            pref: s.notificationPreference,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate notificationPreference.
      final store = container.read(notificationStoreProvider.notifier)
          as _ControllableNotificationStore;
      store
          .setNotificationPreferenceDirect(NotificationPreference.mentionsOnly);

      expect(
        selectNotifyCount,
        1,
        reason: 'notificationPreference change must notify per-field select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: Full-state watch fires on visibleTarget change (anti-pattern proof).
  //
  // Demonstrates the bug: watching the full state causes rebuilds on
  // visibleTarget changes which have zero visible impact on the settings page.
  // -------------------------------------------------------------------------
  test(
    'full-state watch fires on visibleTarget change (anti-pattern proof)',
    () async {
      final container = ProviderContainer(
        overrides: [
          notificationStoreProvider
              .overrideWith(() => _ControllableNotificationStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        notificationStoreProvider,
        (_, __) {},
      );

      // Full-state watch (current pattern).
      int fullStateNotifyCount = 0;
      container.listen(
        notificationStoreProvider,
        (_, __) => fullStateNotifyCount++,
      );

      // Mutate visibleTarget.
      final store = container.read(notificationStoreProvider.notifier)
          as _ControllableNotificationStore;
      store.setVisibleTargetDirect(
        const VisibleTarget(
          serverId: 'server-1',
          surface: NotificationSurface.dm,
          channelId: 'dm-1',
        ),
      );

      expect(
        fullStateNotifyCount,
        greaterThanOrEqualTo(1),
        reason: 'Full-state watch fires on any mutation (proving the bug)',
      );

      keepAlive.close();
    },
  );
}
