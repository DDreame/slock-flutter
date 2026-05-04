import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/core/notifications/realtime_notification_bridge.dart';
import 'package:slock_app/core/realtime/realtime_event_envelope.dart';
import 'package:slock_app/core/realtime/realtime_reduction_ingress.dart';
import 'package:slock_app/core/realtime/providers.dart'
    show realtimeReductionIngressProvider;
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

class _FakeNotificationShowSink {
  final List<Map<String, dynamic>> shown = [];

  Future<void> showLocalNotification(Map<String, dynamic> payload) async {
    shown.add(payload);
  }
}

/// Minimal session store that returns an authenticated state with a
/// configurable userId.
class _FakeSessionStore extends SessionStore {
  _FakeSessionStore({this.userId = 'current-user'});

  final String? userId;

  @override
  SessionState build() => SessionState(
        status: AuthStatus.authenticated,
        token: 'tok',
        userId: userId,
      );
}

/// Build a minimal `message:new` realtime event envelope.
RealtimeEventEnvelope _messageNewEvent({
  required String channelId,
  required String messageId,
  String? senderId,
  String? senderName,
  String content = 'hello',
  String? serverId,
  String? type,
  String? threadId,
}) {
  return RealtimeEventEnvelope(
    eventType: 'message:new',
    scopeKey: channelId,
    receivedAt: DateTime.now(),
    payload: <String, dynamic>{
      'channelId': channelId,
      'id': messageId,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
      'senderType': 'human',
      'messageType': 'message',
      if (senderId != null) 'senderId': senderId,
      if (senderName != null) 'senderName': senderName,
      if (serverId != null) 'serverId': serverId,
      if (type != null) 'type': type,
      if (threadId != null) 'threadId': threadId,
    },
  );
}

void main() {
  late RealtimeReductionIngress ingress;
  late _FakeNotificationShowSink showSink;
  late DiagnosticsCollector diagnostics;
  late ProviderContainer container;

  setUp(() {
    ingress = RealtimeReductionIngress();
    showSink = _FakeNotificationShowSink();
    diagnostics = DiagnosticsCollector();
  });

  tearDown(() async {
    container.dispose();
    await ingress.dispose();
  });

  ProviderContainer buildContainer({
    NotificationState? notificationState,
    String? currentUserId,
  }) {
    final c = ProviderContainer(
      overrides: [
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        diagnosticsCollectorProvider.overrideWithValue(diagnostics),
        realtimeNotificationShowSinkProvider
            .overrideWithValue(showSink.showLocalNotification),
        sessionStoreProvider.overrideWith(
          () => _FakeSessionStore(userId: currentUserId ?? 'current-user'),
        ),
        if (notificationState != null)
          notificationStoreProvider.overrideWith(
            () => _OverriddenNotificationStore(notificationState),
          ),
      ],
    );
    return c;
  }

  group('RealtimeNotificationBridge', () {
    test('message:new triggers showLocalNotification', () async {
      container = buildContainer();
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'ch-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        senderName: 'Alice',
        content: 'Hello world',
        serverId: 'srv-1',
        type: 'channel',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, hasLength(1));
      expect(showSink.shown.first['title'], isNotNull);
      expect(showSink.shown.first['body'], 'Hello world');
      expect(showSink.shown.first['channelId'], 'ch-1');
      expect(showSink.shown.first['serverId'], 'srv-1');
    });

    test('self-message is suppressed', () async {
      container = buildContainer(currentUserId: 'user-1');
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'ch-1',
        messageId: 'msg-1',
        senderId: 'user-1', // same as current user
        content: 'My own message',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, isEmpty);
    });

    test('visible target match suppresses notification', () async {
      container = buildContainer(
        notificationState: const NotificationState(
          lifecycleStatus: AppLifecycleStatus.resumed,
          visibleTarget: VisibleTarget(
            serverId: 'srv-1',
            surface: NotificationSurface.channel,
            channelId: 'ch-1',
          ),
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'ch-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        content: 'Hello',
        serverId: 'srv-1',
        type: 'channel',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, isEmpty);
    });

    test('different channel is not suppressed by visible target', () async {
      container = buildContainer(
        notificationState: const NotificationState(
          lifecycleStatus: AppLifecycleStatus.resumed,
          visibleTarget: VisibleTarget(
            serverId: 'srv-1',
            surface: NotificationSurface.channel,
            channelId: 'ch-other',
          ),
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'ch-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        content: 'Hello',
        serverId: 'srv-1',
        type: 'channel',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, hasLength(1));
    });

    test('muted preference suppresses all notifications', () async {
      container = buildContainer(
        notificationState: const NotificationState(
          notificationPreference: NotificationPreference.mute,
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'ch-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        content: 'Hello',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, isEmpty);
    });

    test('mentionsOnly preference suppresses channel messages', () async {
      container = buildContainer(
        notificationState: const NotificationState(
          notificationPreference: NotificationPreference.mentionsOnly,
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'ch-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        content: 'Hello',
        serverId: 'srv-1',
        type: 'channel',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, isEmpty);
    });

    test('mentionsOnly preference allows DM messages', () async {
      container = buildContainer(
        notificationState: const NotificationState(
          notificationPreference: NotificationPreference.mentionsOnly,
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'dm-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        senderName: 'Bob',
        content: 'DM hello',
        serverId: 'srv-1',
        type: 'dm',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, hasLength(1));
    });

    test('non-message events are ignored', () async {
      container = buildContainer();
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:updated',
        scopeKey: 'ch-1',
        receivedAt: DateTime.now(),
        payload: <String, dynamic>{
          'channelId': 'ch-1',
          'id': 'msg-1',
          'content': 'edited',
        },
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, isEmpty);
    });

    test('diagnostics logged for delivered notification', () async {
      container = buildContainer();
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'ch-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        content: 'Hello',
      ));

      await Future<void>.delayed(Duration.zero);

      final entries = diagnostics.entries
          .where((e) => e.tag == 'notification-bridge')
          .toList();
      expect(entries, isNotEmpty);
      expect(entries.last.message, contains('source=realtime'));
      expect(entries.last.message, contains('delivered'));
    });

    test('diagnostics logged for suppressed notification', () async {
      container = buildContainer(
        notificationState: const NotificationState(
          notificationPreference: NotificationPreference.mute,
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'ch-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        content: 'Hello',
      ));

      await Future<void>.delayed(Duration.zero);

      final entries = diagnostics.entries
          .where((e) => e.tag == 'notification-bridge')
          .toList();
      expect(entries, isNotEmpty);
      expect(entries.last.message, contains('suppressed'));
      expect(entries.last.message, contains('muted'));
    });

    test('thread message with visible thread target is suppressed', () async {
      container = buildContainer(
        notificationState: const NotificationState(
          lifecycleStatus: AppLifecycleStatus.resumed,
          visibleTarget: VisibleTarget(
            serverId: 'srv-1',
            surface: NotificationSurface.thread,
            channelId: 'ch-1',
            threadId: 'thread-1',
          ),
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'ch-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        content: 'Thread reply',
        serverId: 'srv-1',
        type: 'thread',
        threadId: 'thread-1',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, isEmpty);
    });

    test('DM message with visible DM target is suppressed', () async {
      container = buildContainer(
        notificationState: const NotificationState(
          lifecycleStatus: AppLifecycleStatus.resumed,
          visibleTarget: VisibleTarget(
            serverId: 'srv-1',
            surface: NotificationSurface.dm,
            channelId: 'dm-1',
          ),
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'dm-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        content: 'DM hello',
        serverId: 'srv-1',
        type: 'dm',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, isEmpty);
    });
  });
}

class _OverriddenNotificationStore extends NotificationStore {
  _OverriddenNotificationStore(this._initialState);

  final NotificationState _initialState;

  @override
  NotificationState build() => _initialState;
}
