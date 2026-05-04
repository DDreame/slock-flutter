import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_deep_link_helper.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/core/realtime/realtime_event_envelope.dart';
import 'package:slock_app/core/realtime/realtime_reduction_ingress.dart';
import 'package:slock_app/core/realtime/providers.dart'
    show realtimeReductionIngressProvider;
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

const _tag = 'notification-bridge';
const _messageNewEventType = 'message:new';

/// Function type for showing local notifications. Defaults to the
/// platform [NotificationInitializer.showLocalNotification], but can
/// be overridden in tests.
typedef ShowLocalNotification = Future<void> Function(
  Map<String, dynamic> payload,
);

/// Override seam so tests can capture [showLocalNotification] calls
/// without a real platform bridge.
final realtimeNotificationShowSinkProvider =
    Provider<ShowLocalNotification>((ref) {
  final initializer = ref.watch(notificationInitializerProvider);
  return initializer.showLocalNotification;
});

/// Bridges realtime WebSocket events to local notifications.
///
/// Listens to [RealtimeReductionIngress.acceptedEvents] for
/// `message:new` events and shows local notifications for messages
/// that are not self-authored and not visible to the user.
///
/// This provides a client-side notification path that works
/// independent of server-sent push (FCM/APNs). On Android the
/// foreground service keeps the socket alive; on iOS the socket is
/// active while the app is in foreground or active background.
///
/// Applies the same suppression rules as the native push path:
/// - Mute preference → suppress all
/// - MentionsOnly preference → suppress non-DM
/// - Visible target match → suppress (user is looking at it)
/// - Self-message → suppress
final realtimeNotificationBridgeProvider = Provider<void>((ref) {
  final ingress = ref.watch(realtimeReductionIngressProvider);
  final diagnostics = ref.read(diagnosticsCollectorProvider);
  final showNotification = ref.read(realtimeNotificationShowSinkProvider);
  final policy = ref.watch(foregroundNotificationPolicyProvider);

  final subscription = ingress.acceptedEvents.listen((event) {
    if (event.eventType != _messageNewEventType) return;

    final payload = event.payload;
    if (payload is! Map) return;
    final map = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload);

    final senderId = map['senderId'] as String?;
    final channelId = map['channelId'] as String?;
    final content = map['content'] as String? ?? '';
    final senderName = map['senderName'] as String?;

    // Suppress self-messages.
    final currentUserId = ref.read(sessionStoreProvider).userId;
    if (currentUserId != null &&
        senderId != null &&
        senderId == currentUserId) {
      diagnostics.info(
        _tag,
        'source=realtime, suppressed=self, '
        'channelId=$channelId',
      );
      return;
    }

    // Check notification preference.
    final notificationState = ref.read(notificationStoreProvider);
    final preference = notificationState.notificationPreference;

    if (preference == NotificationPreference.mute) {
      diagnostics.info(
        _tag,
        'source=realtime, suppressed=muted, '
        'channelId=$channelId',
      );
      return;
    }

    // Parse notification target for suppression checks.
    final target = parseNotificationTarget(map);

    if (preference == NotificationPreference.mentionsOnly) {
      if (target == null || target.surface != NotificationSurface.dm) {
        diagnostics.info(
          _tag,
          'source=realtime, suppressed=mentionsOnly, '
          'channelId=$channelId',
        );
        return;
      }
    }

    // Check visible target suppression.
    if (target != null) {
      final suppress = policy.shouldSuppress(
        lifecycleStatus: notificationState.lifecycleStatus,
        visibleTarget: notificationState.visibleTarget,
        incomingTarget: target,
      );
      if (suppress) {
        diagnostics.info(
          _tag,
          'source=realtime, suppressed=visibleTarget, '
          'channelId=$channelId',
        );
        return;
      }
    }

    // Build local notification payload.
    final notificationPayload = <String, dynamic>{
      'title': senderName ?? 'New message',
      'body': content,
      'channelId': channelId,
      if (map['serverId'] != null) 'serverId': map['serverId'],
      if (map['type'] != null) 'type': map['type'],
      if (map['threadId'] != null) 'threadId': map['threadId'],
      if (map['id'] != null) 'messageId': map['id'],
      'slock.source': 'realtime',
    };

    diagnostics.info(
      _tag,
      'source=realtime, delivered, '
      'channelId=$channelId',
    );

    unawaited(showNotification(notificationPayload));
  });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});
