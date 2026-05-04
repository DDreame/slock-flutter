import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/core/realtime/realtime_reduction_ingress.dart';
import 'package:slock_app/core/realtime/providers.dart'
    show realtimeReductionIngressProvider;
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/features/threads/application/known_thread_channel_ids_provider.dart';
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

/// Result of resolving a notification target from app state.
///
/// When [target] is non-null, the channelId was found in the home
/// list and the surface/serverId are known. When null, the channel
/// is not in any loaded list (archived, not-yet-loaded, system, etc.)
/// and [surfaceName] will be `'unknown'`.
class _ResolvedTarget {
  const _ResolvedTarget({
    this.target,
    required this.serverId,
    required this.surfaceName,
    this.parentChannelId,
    this.parentMessageId,
  });

  final NotificationTarget? target;
  final String? serverId;

  /// Human-readable surface name for the notification payload
  /// (`'channel'`, `'dm'`, `'thread'`, or `'unknown'`).
  final String surfaceName;

  /// For threads: the parent channel ID used in deep link routing.
  /// Null for non-thread targets.
  final String? parentChannelId;

  /// For threads: the parent message ID used in deep link routing.
  /// Null for non-thread targets.
  final String? parentMessageId;
}

/// Resolves a [NotificationTarget] from the home list state by
/// matching [channelId] against channels, DMs, and known threads.
///
/// Returns a [_ResolvedTarget] with `target == null` when the
/// channelId is not found in any loaded list — the caller should
/// still deliver the notification but log `targetResolved=false`.
_ResolvedTarget _resolveTarget(Ref ref, String channelId) {
  final homeState = ref.read(homeListStoreProvider);
  final serverId = homeState.serverScopeId?.value;

  // Scan channels (pinnedChannels + channels).
  for (final ch in homeState.pinnedChannels) {
    if (ch.scopeId.value == channelId) {
      return _ResolvedTarget(
        serverId: serverId,
        surfaceName: 'channel',
        target: serverId != null
            ? NotificationTarget(
                serverId: serverId,
                surface: NotificationSurface.channel,
                channelId: channelId,
              )
            : null,
      );
    }
  }
  for (final ch in homeState.channels) {
    if (ch.scopeId.value == channelId) {
      return _ResolvedTarget(
        serverId: serverId,
        surfaceName: 'channel',
        target: serverId != null
            ? NotificationTarget(
                serverId: serverId,
                surface: NotificationSurface.channel,
                channelId: channelId,
              )
            : null,
      );
    }
  }

  // Scan DMs (pinned + regular + hidden).
  for (final dm in homeState.pinnedDirectMessages) {
    if (dm.scopeId.value == channelId) {
      return _ResolvedTarget(
        serverId: serverId,
        surfaceName: 'dm',
        target: serverId != null
            ? NotificationTarget(
                serverId: serverId,
                surface: NotificationSurface.dm,
                channelId: channelId,
              )
            : null,
      );
    }
  }
  for (final dm in homeState.directMessages) {
    if (dm.scopeId.value == channelId) {
      return _ResolvedTarget(
        serverId: serverId,
        surfaceName: 'dm',
        target: serverId != null
            ? NotificationTarget(
                serverId: serverId,
                surface: NotificationSurface.dm,
                channelId: channelId,
              )
            : null,
      );
    }
  }
  for (final dm in homeState.hiddenDirectMessages) {
    if (dm.scopeId.value == channelId) {
      return _ResolvedTarget(
        serverId: serverId,
        surfaceName: 'dm',
        target: serverId != null
            ? NotificationTarget(
                serverId: serverId,
                surface: NotificationSurface.dm,
                channelId: channelId,
              )
            : null,
      );
    }
  }

  // Check known thread channel IDs. When a match is found, resolve
  // the parent channel/message identity from threadItems so that
  // the NotificationTarget uses the same identity as visible thread
  // targets (parentChannelId + parentMessageId) — not the raw
  // threadChannelId from the event.
  if (serverId != null) {
    final knownThreadIds = ref.read(knownThreadChannelIdsProvider);
    final qualifiedId = threadChannelKey(serverId, channelId);
    if (knownThreadIds.contains(qualifiedId)) {
      // Look up full thread route metadata from the home thread
      // inbox so we can build a correct thread target.
      for (final item in homeState.threadItems) {
        if (item.routeTarget.threadChannelId == channelId) {
          return _ResolvedTarget(
            serverId: serverId,
            surfaceName: 'thread',
            target: NotificationTarget(
              serverId: serverId,
              surface: NotificationSurface.thread,
              channelId: item.routeTarget.parentChannelId,
              threadId: item.routeTarget.parentMessageId,
            ),
            parentChannelId: item.routeTarget.parentChannelId,
            parentMessageId: item.routeTarget.parentMessageId,
          );
        }
      }
      // Known thread channel but no route metadata available
      // (thread not in inbox). Fall back to unknown rather than
      // emitting a malformed thread target.
      return _ResolvedTarget(
        serverId: serverId,
        surfaceName: 'unknown',
        target: null,
      );
    }
  }

  // Not found in any list — unknown channel type.
  return _ResolvedTarget(
    serverId: serverId,
    surfaceName: 'unknown',
    target: null,
  );
}

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
/// Resolves channel type and serverId from [HomeListStore] state
/// rather than expecting them in the raw realtime payload (which
/// only carries `channelId`).
///
/// Applies the same suppression rules as the native push path:
/// - Self-message → suppress
/// - Mute preference → suppress all
/// - MentionsOnly preference → suppress non-DM
/// - Visible target match → suppress (user is looking at it)
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
    final messageId = map['id'] as String?;

    if (channelId == null) return;

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

    // Resolve notification target from app state.
    final resolved = _resolveTarget(ref, channelId);

    if (preference == NotificationPreference.mentionsOnly) {
      // When target could not be resolved, we cannot confirm it's a
      // DM — suppress to avoid leaking non-DM notifications.
      if (resolved.target == null ||
          resolved.target!.surface != NotificationSurface.dm) {
        diagnostics.info(
          _tag,
          'source=realtime, suppressed=mentionsOnly, '
          'channelId=$channelId, '
          'targetResolved=${resolved.target != null}',
        );
        return;
      }
    }

    // Check visible target suppression.
    if (resolved.target != null) {
      final suppress = policy.shouldSuppress(
        lifecycleStatus: notificationState.lifecycleStatus,
        visibleTarget: notificationState.visibleTarget,
        incomingTarget: resolved.target!,
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

    // Build local notification payload with resolved routing
    // metadata for deep link resolution. For threads, use the
    // parent channel/message identity (not the threadChannelId).
    final notificationPayload = <String, dynamic>{
      'title': senderName ?? 'New message',
      'body': content,
      'channelId': resolved.parentChannelId ?? channelId,
      if (resolved.serverId != null) 'serverId': resolved.serverId,
      'type': resolved.surfaceName,
      if (resolved.parentMessageId != null)
        'threadId': resolved.parentMessageId,
      if (messageId != null) 'messageId': messageId,
      'slock.source': 'realtime',
    };

    diagnostics.info(
      _tag,
      'source=realtime, delivered, '
      'channelId=$channelId, '
      'targetResolved=${resolved.target != null}',
    );

    unawaited(showNotification(notificationPayload));
  });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});
