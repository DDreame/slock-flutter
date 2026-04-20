import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_deep_link_helper.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

final notificationForegroundSuppressionBindingProvider = Provider<void>((ref) {
  final initializer = ref.watch(notificationInitializerProvider);
  final policy = ref.watch(foregroundNotificationPolicyProvider);

  final subscription = initializer.onForegroundMessage.listen((payload) {
    final target = parseNotificationTarget(payload);

    if (target != null) {
      final state = ref.read(notificationStoreProvider);
      final suppress = policy.shouldSuppress(
        lifecycleStatus: state.lifecycleStatus,
        visibleTarget: state.visibleTarget,
        incomingTarget: target,
      );
      if (suppress) return;
    }

    unawaited(initializer.showLocalNotification(payload));
  });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});
