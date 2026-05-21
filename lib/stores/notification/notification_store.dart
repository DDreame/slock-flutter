import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_deep_link_helper.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/core/storage/notification_storage_keys.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/stores/notification/notification_state.dart';

final notificationStoreProvider =
    NotifierProvider<NotificationStore, NotificationState>(
  NotificationStore.new,
);

class NotificationStore extends Notifier<NotificationState> {
  bool _initialized = false;
  StreamSubscription<Map<String, dynamic>>? _tapSubscription;
  StreamSubscription<String>? _tokenSubscription;

  @override
  NotificationState build() {
    ref.onDispose(() {
      _tapSubscription?.cancel();
      _tapSubscription = null;
      _tokenSubscription?.cancel();
      _tokenSubscription = null;
      _initialized = false;
    });
    return const NotificationState();
  }

  NotificationInitializer get _initializer =>
      ref.read(notificationInitializerProvider);

  SecureStorage get _storage => ref.read(secureStorageProvider);

  DiagnosticsCollector get _diagnostics =>
      ref.read(diagnosticsCollectorProvider);

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _initializer.init();
      final nativeStatus = await _initializer.getPermissionStatus();
      state = state.copyWith(permissionStatus: nativeStatus);
      await restorePushToken();
      await restoreNotificationPreference();
      final initial = await _initializer.getInitialNotification();
      if (initial != null) {
        handleNotificationTap(initial);
      }
      _tapSubscription =
          _initializer.onNotificationTapped.listen(handleNotificationTap);
      _tokenSubscription = _initializer.onTokenChanged.listen(_handleTokenPush);
      _initialized = true;
    } catch (_) {
      _tapSubscription?.cancel();
      _tapSubscription = null;
      _tokenSubscription?.cancel();
      _tokenSubscription = null;
      rethrow;
    }
    // Auto-refresh push token when permission is already granted.
    await _autoRefreshTokenIfPermitted();
  }

  /// Requests notification permission if the status is still [unknown],
  /// meaning the user has never been prompted (Android 13+ first-ask
  /// state). Safe to call on every launch — skips when permission is
  /// already decided.
  Future<void> onboardPermissionIfNeeded() async {
    if (state.permissionStatus != NotificationPermissionStatus.unknown) {
      return;
    }
    await requestPermission();
  }

  void handleNotificationTap(Map<String, dynamic> payload) {
    final route = resolveNotificationRoute(payload);
    if (route != null) {
      ref.read(pendingDeepLinkProvider.notifier).state = route;
    }
  }

  Future<void> requestPermission() async {
    final status = await _initializer.requestPermission();
    state = state.copyWith(permissionStatus: status);
    _diagnostics.add(DiagnosticsEntry(
      timestamp: DateTime.now(),
      level: DiagnosticsLevel.info,
      tag: 'notification',
      message: 'Permission request result: ${status.name}',
    ));
    // Auto-refresh push token when permission was just granted.
    await _autoRefreshTokenIfPermitted();
  }

  Future<void> refreshToken({String? platform}) async {
    platform ??= Platform.operatingSystem;
    final token = await _initializer.getToken();
    if (token == null) return;
    final now = DateTime.now();
    final tokenChanged = token != state.pushToken;
    final platformChanged = platform != state.pushTokenPlatform;
    // Always update the timestamp to reflect the last registration
    // attempt, even when the token and platform are unchanged.
    state = state.copyWith(
      pushToken: token,
      pushTokenPlatform: platform,
      pushTokenUpdatedAt: now,
    );
    await _persistPushToken(token, now, platform: platform);
    if (tokenChanged || platformChanged) {
      _diagnostics.add(DiagnosticsEntry(
        timestamp: DateTime.now(),
        level: DiagnosticsLevel.info,
        tag: 'notification',
        message: tokenChanged ? 'Push token updated' : 'Platform updated',
        metadata: {'platform': platform},
      ));
    }
  }

  Future<void> restorePushToken() async {
    // Batch all storage reads in parallel instead of sequential awaits.
    final results = await Future.wait([
      _storage.read(key: NotificationStorageKeys.pushToken),
      _storage.read(key: NotificationStorageKeys.pushTokenPlatform),
      _storage.read(key: NotificationStorageKeys.pushTokenUpdatedAt),
    ]);
    final token = results[0];
    final platform = results[1];
    final updatedAtStr = results[2];
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

  Future<void> restoreNotificationPreference() async {
    final repo = ref.read(notificationPreferenceRepositoryProvider);
    final preference = await repo.getPreference();
    state = state.copyWith(notificationPreference: preference);
  }

  Future<void> setNotificationPreference(
    NotificationPreference preference,
  ) async {
    final repo = ref.read(notificationPreferenceRepositoryProvider);
    await repo.setPreference(preference);
    state = state.copyWith(notificationPreference: preference);
    _diagnostics.add(DiagnosticsEntry(
      timestamp: DateTime.now(),
      level: DiagnosticsLevel.info,
      tag: 'notification',
      message: 'Preference changed to ${preference.storageValue}',
    ));
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

  void setCurrentUserId(String? userId) {
    if (userId == null) {
      state = state.copyWith(clearCurrentUserId: true);
    } else {
      state = state.copyWith(currentUserId: userId);
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

  /// Handle push-based token delivery from native platform.
  ///
  /// This fires when the native APNs callback delivers a new/refreshed
  /// token via the EventChannel, solving the race where [getToken]
  /// returns null at init time.
  void _handleTokenPush(String token) {
    final platform = Platform.operatingSystem;
    final now = DateTime.now();
    final tokenChanged = token != state.pushToken;
    state = state.copyWith(
      pushToken: token,
      pushTokenPlatform: platform,
      pushTokenUpdatedAt: now,
    );
    unawaited(_persistPushToken(token, now, platform: platform));
    if (tokenChanged) {
      _diagnostics.add(DiagnosticsEntry(
        timestamp: now,
        level: DiagnosticsLevel.info,
        tag: 'notification',
        message: 'Push token updated, source=${platform}Token',
        metadata: {'platform': platform},
      ));
    }
  }

  Future<void> _autoRefreshTokenIfPermitted() async {
    final status = state.permissionStatus;
    if (status == NotificationPermissionStatus.granted ||
        status == NotificationPermissionStatus.provisional) {
      await refreshToken();
    }
  }

  Future<void> _persistPushToken(
    String token,
    DateTime updatedAt, {
    String? platform,
  }) async {
    // Batch all storage writes in parallel instead of sequential awaits.
    await Future.wait([
      _storage.write(
        key: NotificationStorageKeys.pushToken,
        value: token,
      ),
      _storage.write(
        key: NotificationStorageKeys.pushTokenUpdatedAt,
        value: updatedAt.toIso8601String(),
      ),
      if (platform != null)
        _storage.write(
          key: NotificationStorageKeys.pushTokenPlatform,
          value: platform,
        ),
    ]);
  }
}
