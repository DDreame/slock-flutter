import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/notification_target.dart';

enum AppLifecycleStatus { resumed, inactive, paused, detached }

abstract class ForegroundNotificationPolicy {
  bool shouldSuppress({
    required AppLifecycleStatus lifecycleStatus,
    required VisibleTarget? visibleTarget,
    required NotificationTarget incomingTarget,
  });
}

class DefaultForegroundNotificationPolicy
    implements ForegroundNotificationPolicy {
  @override
  bool shouldSuppress({
    required AppLifecycleStatus lifecycleStatus,
    required VisibleTarget? visibleTarget,
    required NotificationTarget incomingTarget,
  }) {
    if (lifecycleStatus != AppLifecycleStatus.resumed) return false;
    if (visibleTarget == null) return false;
    return visibleTarget.matches(incomingTarget);
  }
}

final foregroundNotificationPolicyProvider =
    Provider<ForegroundNotificationPolicy>((ref) {
  return DefaultForegroundNotificationPolicy();
});
