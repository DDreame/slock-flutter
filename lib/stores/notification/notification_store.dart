import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_deep_link_helper.dart';
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
  bool _initialized = false;
  StreamSubscription<Map<String, dynamic>>? _tapSubscription;

  @override
  NotificationState build() {
    ref.onDispose(() {
      _tapSubscription?.cancel();
      _tapSubscription = null;
      _initialized = false;
    });
    return const NotificationState();
  }

  NotificationInitializer get _initializer =>
      ref.read(notificationInitializerProvider);

  SecureStorage get _storage => ref.read(secureStorageProvider);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _initializer.init();
    await restorePushToken();
    final initial = await _initializer.getInitialNotification();
    if (initial != null) {
      handleNotificationTap(initial);
    }
    _tapSubscription =
        _initializer.onNotificationTapped.listen(handleNotificationTap);
  }

  void handleNotificationTap(Map<String, dynamic> payload) {
    final route = resolveNotificationRoute(payload);
    if (route != null && isConversationDeepLink(route)) {
      ref.read(pendingDeepLinkProvider.notifier).state = route;
    }
  }

  Future<void> requestPermission() async {
    final status = await _initializer.requestPermission();
    state = state.copyWith(permissionStatus: status);
  }

  Future<void> refreshToken({String? platform}) async {
    final token = await _initializer.getToken();
    if (token == null) return;
    final tokenChanged = token != state.pushToken;
    final platformChanged =
        platform != null && platform != state.pushTokenPlatform;
    if (tokenChanged || platformChanged) {
      final now = DateTime.now();
      state = state.copyWith(
        pushToken: token,
        pushTokenPlatform: platform,
        pushTokenUpdatedAt: now,
      );
      await _persistPushToken(token, now, platform: platform);
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
    } else {
      state = state.copyWith(
        clearPushToken: true,
        clearPushTokenPlatform: true,
        clearPushTokenUpdatedAt: true,
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

  Future<void> _persistPushToken(
    String token,
    DateTime updatedAt, {
    String? platform,
  }) async {
    await _storage.write(
      key: NotificationStorageKeys.pushToken,
      value: token,
    );
    await _storage.write(
      key: NotificationStorageKeys.pushTokenUpdatedAt,
      value: updatedAt.toIso8601String(),
    );
    if (platform != null) {
      await _storage.write(
        key: NotificationStorageKeys.pushTokenPlatform,
        value: platform,
      );
    }
  }
}
