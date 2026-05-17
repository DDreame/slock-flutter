import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_deep_link_helper.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

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
        'source=iosRemotePush, suppressed=muted, '
        'channelId=$channelId',
      );
      return;
    }

    // Per-channel mute: suppress notifications for individually muted
    // channels/DMs. Uses composite key to avoid cross-server collisions.
    if (channelId != null) {
      final serverId = payload['serverId'] as String?;
      if (serverId != null) {
        final mutedIds = ref.read(channelMutedIdsProvider);
        final key = ChannelNotificationPreferenceRepository.compositeKey(
          serverId,
          channelId,
        );
        if (mutedIds.contains(key)) {
          diagnostics.info(
            _tag,
            'source=iosRemotePush, suppressed=channelMuted, '
            'channelId=$channelId',
          );
          return;
        }
      }
    }

    // Self-sender suppression: don't show notifications for own messages.
    // Read userId from session store (production path) with fallback to
    // notification state (test injection path).
    final senderId = payload['senderId'] as String?;
    final currentUserId = ref.read(sessionStoreProvider).userId ??
        notificationState.currentUserId;
    if (senderId != null &&
        currentUserId != null &&
        senderId == currentUserId) {
      diagnostics.info(
        _tag,
        'source=iosRemotePush, suppressed=self, '
        'channelId=$channelId',
      );
      return;
    }

    if (preference == NotificationPreference.mentionsOnly) {
      final target = parseNotificationTarget(payload);
      if (target == null || target.surface != NotificationSurface.dm) {
        diagnostics.info(
          _tag,
          'source=iosRemotePush, suppressed=mentionsOnly, '
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
          'source=iosRemotePush, suppressed=visibleTarget, '
          'channelId=$channelId',
        );
        return;
      }
    }

    diagnostics.info(
      _tag,
      'source=iosForegroundRepost, delivered, '
      'channelId=$channelId',
    );

    unawaited(initializer.showLocalNotification(payload));
  });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});
