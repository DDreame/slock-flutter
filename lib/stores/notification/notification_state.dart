import 'package:flutter/foundation.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';

@immutable
class NotificationState {
  final AppLifecycleStatus lifecycleStatus;
  final VisibleTarget? visibleTarget;
  final String? pushToken;
  final String? pushTokenPlatform;
  final DateTime? pushTokenUpdatedAt;
  final NotificationPermissionStatus permissionStatus;

  const NotificationState({
    this.lifecycleStatus = AppLifecycleStatus.resumed,
    this.visibleTarget,
    this.pushToken,
    this.pushTokenPlatform,
    this.pushTokenUpdatedAt,
    this.permissionStatus = NotificationPermissionStatus.unknown,
  });

  NotificationState copyWith({
    AppLifecycleStatus? lifecycleStatus,
    VisibleTarget? visibleTarget,
    String? pushToken,
    String? pushTokenPlatform,
    DateTime? pushTokenUpdatedAt,
    NotificationPermissionStatus? permissionStatus,
    bool clearVisibleTarget = false,
    bool clearPushToken = false,
    bool clearPushTokenPlatform = false,
    bool clearPushTokenUpdatedAt = false,
  }) {
    return NotificationState(
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
      visibleTarget:
          clearVisibleTarget ? null : (visibleTarget ?? this.visibleTarget),
      pushToken: clearPushToken ? null : (pushToken ?? this.pushToken),
      pushTokenPlatform: clearPushTokenPlatform
          ? null
          : (pushTokenPlatform ?? this.pushTokenPlatform),
      pushTokenUpdatedAt: clearPushTokenUpdatedAt
          ? null
          : (pushTokenUpdatedAt ?? this.pushTokenUpdatedAt),
      permissionStatus: permissionStatus ?? this.permissionStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationState &&
          runtimeType == other.runtimeType &&
          lifecycleStatus == other.lifecycleStatus &&
          visibleTarget == other.visibleTarget &&
          pushToken == other.pushToken &&
          pushTokenPlatform == other.pushTokenPlatform &&
          pushTokenUpdatedAt == other.pushTokenUpdatedAt &&
          permissionStatus == other.permissionStatus;

  @override
  int get hashCode => Object.hash(
        lifecycleStatus,
        visibleTarget,
        pushToken,
        pushTokenPlatform,
        pushTokenUpdatedAt,
        permissionStatus,
      );
}
