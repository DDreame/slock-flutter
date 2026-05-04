import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_deep_link_helper.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

const _tag = 'notification-bridge';

final notificationForegroundSuppressionBindingProvider = Provider<void>((ref) {
  final initializer = ref.watch(notificationInitializerProvider);
  final policy = ref.watch(foregroundNotificationPolicyProvider);
  final diagnostics = ref.read(diagnosticsCollectorProvider);

  final subscription = initializer.onForegroundMessage.listen((payload) {
    final notificationState = ref.read(notificationStoreProvider);
    final preference = notificationState.notificationPreference;
    final channelId = payload['channelId'] as String?;

    if (preference == NotificationPreference.mute) {
      diagnostics.info(
        _tag,
        'source=nativePush, suppressed=muted, '
        'channelId=$channelId',
      );
      return;
    }

    if (preference == NotificationPreference.mentionsOnly) {
      final target = parseNotificationTarget(payload);
      if (target == null || target.surface != NotificationSurface.dm) {
        diagnostics.info(
          _tag,
          'source=nativePush, suppressed=mentionsOnly, '
          'channelId=$channelId',
        );
        return;
      }
    }

    final target = parseNotificationTarget(payload);

    if (target != null) {
      final suppress = policy.shouldSuppress(
        lifecycleStatus: notificationState.lifecycleStatus,
        visibleTarget: notificationState.visibleTarget,
        incomingTarget: target,
      );
      if (suppress) {
        diagnostics.info(
          _tag,
          'source=nativePush, suppressed=visibleTarget, '
          'channelId=$channelId',
        );
        return;
      }
    }

    diagnostics.info(
      _tag,
      'source=nativePush, delivered, '
      'channelId=$channelId',
    );

    unawaited(initializer.showLocalNotification(payload));
  });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});
