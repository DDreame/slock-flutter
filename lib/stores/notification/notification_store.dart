import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/core/storage/notification_storage_keys.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/stores/notification/notification_state.dart';

final notificationStoreProvider =
    NotifierProvider<NotificationStore, NotificationState>(
  NotificationStore.new,
);

class NotificationStore extends Notifier<NotificationState> {
  @override
  NotificationState build() => const NotificationState();

  NotificationInitializer get _initializer =>
      ref.read(notificationInitializerProvider);

  SecureStorage get _storage => ref.read(secureStorageProvider);

  Future<void> init() async {
    await _initializer.init();
    await restorePushToken();
  }

  Future<void> requestPermission() async {
    final status = await _initializer.requestPermission();
    state = state.copyWith(permissionStatus: status);
  }

  Future<void> refreshToken() async {
    final token = await _initializer.getToken();
    if (token != null && token != state.pushToken) {
      final now = DateTime.now();
      state = state.copyWith(
        pushToken: token,
        pushTokenUpdatedAt: now,
      );
      await _persistPushToken(token, now);
    }
  }

  Future<void> restorePushToken() async {
    final token = await _storage.read(
      key: NotificationStorageKeys.pushToken,
    );
    final platform = await _storage.read(
      key: NotificationStorageKeys.pushTokenPlatform,
    );
    final updatedAtStr = await _storage.read(
      key: NotificationStorageKeys.pushTokenUpdatedAt,
    );
    if (token != null) {
      state = state.copyWith(
        pushToken: token,
        pushTokenPlatform: platform,
        pushTokenUpdatedAt:
            updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null,
      );
    }
  }

  void setLifecycleStatus(AppLifecycleStatus status) {
    state = state.copyWith(lifecycleStatus: status);
  }

  void setVisibleTarget(VisibleTarget? target) {
    if (target == null) {
      state = state.copyWith(clearVisibleTarget: true);
    } else {
      state = state.copyWith(visibleTarget: target);
    }
  }

  Future<void> clearPushToken() async {
    state = state.copyWith(
      clearPushToken: true,
      clearPushTokenPlatform: true,
      clearPushTokenUpdatedAt: true,
    );
    await NotificationStorageKeys.clear(_storage);
  }

  Future<void> _persistPushToken(String token, DateTime updatedAt) async {
    await _storage.write(
      key: NotificationStorageKeys.pushToken,
      value: token,
    );
    await _storage.write(
      key: NotificationStorageKeys.pushTokenUpdatedAt,
      value: updatedAt.toIso8601String(),
    );
  }
}
