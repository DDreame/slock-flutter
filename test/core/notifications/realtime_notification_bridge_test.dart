import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/core/notifications/realtime_notification_bridge.dart';
import 'package:slock_app/core/realtime/realtime_event_envelope.dart';
import 'package:slock_app/core/realtime/realtime_reduction_ingress.dart';
import 'package:slock_app/core/realtime/providers.dart'
    show realtimeReductionIngressProvider;
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/features/threads/application/known_thread_channel_ids_provider.dart';
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

/// HomeListStore override that returns a pre-built state.
class _FakeHomeListStore extends HomeListStore {
  _FakeHomeListStore(this._state);

  final HomeListState _state;

  @override
  HomeListState build() => _state;
}

/// Server scope ID constant used across tests.
const _testServerId = 'srv-1';
final _testServerScope = ServerScopeId(_testServerId);

/// Build a lean `message:new` realtime event envelope matching the
/// actual production payload shape — no `serverId` or `type` fields.
RealtimeEventEnvelope _messageNewEvent({
  required String channelId,
  required String messageId,
  String? senderId,
  String? senderName,
  String content = 'hello',
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
      if (threadId != null) 'threadId': threadId,
    },
  );
}

/// Default home list state with one channel and one DM.
HomeListState _defaultHomeState() => HomeListState(
      serverScopeId: _testServerScope,
      status: HomeListStatus.success,
      channels: [
        HomeChannelSummary(
          scopeId: ChannelScopeId(
            serverId: _testServerScope,
            value: 'ch-1',
          ),
          name: '#general',
        ),
      ],
      directMessages: [
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(
            serverId: _testServerScope,
            value: 'dm-1',
          ),
          title: 'Alice',
        ),
      ],
    );

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
    HomeListState? homeState,
    Set<String> knownThreadIds = const {},
  }) {
    final homeListState = homeState ?? _defaultHomeState();
    final c = ProviderContainer(
      overrides: [
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        diagnosticsCollectorProvider.overrideWithValue(diagnostics),
        realtimeNotificationShowSinkProvider
            .overrideWithValue(showSink.showLocalNotification),
        sessionStoreProvider.overrideWith(
          () => _FakeSessionStore(userId: currentUserId ?? 'current-user'),
        ),
        homeListStoreProvider.overrideWith(
          () => _FakeHomeListStore(homeListState),
        ),
        knownThreadChannelIdsProvider.overrideWith((ref) => knownThreadIds),
        if (notificationState != null)
          notificationStoreProvider.overrideWith(
            () => _OverriddenNotificationStore(notificationState),
          ),
      ],
    );
    return c;
  }

  group('RealtimeNotificationBridge — lean payload', () {
    test(
        'channel message triggers showLocalNotification with resolved '
        'serverId and type', () async {
      container = buildContainer();
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'ch-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        senderName: 'Alice',
        content: 'Hello world',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, hasLength(1));
      final payload = showSink.shown.first;
      expect(payload['title'], 'Alice');
      expect(payload['body'], 'Hello world');
      expect(payload['channelId'], 'ch-1');
      // Resolved from home list state, not from raw payload:
      expect(payload['serverId'], _testServerId);
      expect(payload['type'], 'channel');
    });

    test('DM message resolves type=dm from home list', () async {
      container = buildContainer();
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'dm-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        senderName: 'Bob',
        content: 'DM hello',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, hasLength(1));
      final payload = showSink.shown.first;
      expect(payload['type'], 'dm');
      expect(payload['serverId'], _testServerId);
    });

    test(
        'unknown channelId still delivers notification with '
        'type=unknown', () async {
      container = buildContainer();
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'unknown-ch',
        messageId: 'msg-1',
        senderId: 'other-user',
        senderName: 'Carol',
        content: 'Hello from unknown',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, hasLength(1));
      final payload = showSink.shown.first;
      expect(payload['type'], 'unknown');
      expect(payload['body'], 'Hello from unknown');
    });

    test(
        'thread channelId resolves type=thread via '
        'knownThreadChannelIdsProvider', () async {
      container = buildContainer(
        knownThreadIds: {threadChannelKey(_testServerId, 'thread-ch-1')},
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'thread-ch-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        senderName: 'Dave',
        content: 'Thread reply',
        threadId: 'thread-parent-1',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, hasLength(1));
      final payload = showSink.shown.first;
      expect(payload['type'], 'thread');
      expect(payload['threadId'], 'thread-parent-1');
      expect(payload['serverId'], _testServerId);
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

    test('visible target match suppresses channel notification', () async {
      container = buildContainer(
        notificationState: const NotificationState(
          lifecycleStatus: AppLifecycleStatus.resumed,
          visibleTarget: VisibleTarget(
            serverId: _testServerId,
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
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, isEmpty);
    });

    test('different channel is not suppressed by visible target', () async {
      container = buildContainer(
        notificationState: const NotificationState(
          lifecycleStatus: AppLifecycleStatus.resumed,
          visibleTarget: VisibleTarget(
            serverId: _testServerId,
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
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, hasLength(1));
    });

    test('mentionsOnly suppresses unknown channelId (cannot confirm DM)',
        () async {
      container = buildContainer(
        notificationState: const NotificationState(
          notificationPreference: NotificationPreference.mentionsOnly,
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'unknown-ch',
        messageId: 'msg-1',
        senderId: 'other-user',
        content: 'Hello',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, isEmpty);
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

    test('visible DM target suppresses DM notification', () async {
      container = buildContainer(
        notificationState: const NotificationState(
          lifecycleStatus: AppLifecycleStatus.resumed,
          visibleTarget: VisibleTarget(
            serverId: _testServerId,
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
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, isEmpty);
    });

    test('thread message with visible thread target is suppressed', () async {
      container = buildContainer(
        knownThreadIds: {threadChannelKey(_testServerId, 'thread-ch-1')},
        notificationState: const NotificationState(
          lifecycleStatus: AppLifecycleStatus.resumed,
          visibleTarget: VisibleTarget(
            serverId: _testServerId,
            surface: NotificationSurface.thread,
            channelId: 'thread-ch-1',
            threadId: 'thread-parent-1',
          ),
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'thread-ch-1',
        messageId: 'msg-1',
        senderId: 'other-user',
        content: 'Thread reply',
        threadId: 'thread-parent-1',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, isEmpty);
    });

    test(
        'unknown channelId skips visible-target suppression '
        '(no target to compare)', () async {
      container = buildContainer(
        notificationState: const NotificationState(
          lifecycleStatus: AppLifecycleStatus.resumed,
          visibleTarget: VisibleTarget(
            serverId: _testServerId,
            surface: NotificationSurface.channel,
            channelId: 'ch-1',
          ),
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      // Message for unknown channel — visible target suppression
      // should not fire because we cannot resolve the target.
      ingress.accept(_messageNewEvent(
        channelId: 'unknown-ch',
        messageId: 'msg-1',
        senderId: 'other-user',
        content: 'Hello',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, hasLength(1));
    });
  });

  group('RealtimeNotificationBridge — diagnostics', () {
    test('logs targetResolved=true for delivered known channel', () async {
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
      expect(entries.last.message, contains('targetResolved=true'));
    });

    test('logs targetResolved=false for delivered unknown channel', () async {
      container = buildContainer();
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'unknown-ch',
        messageId: 'msg-1',
        senderId: 'other-user',
        content: 'Hello',
      ));

      await Future<void>.delayed(Duration.zero);

      final entries = diagnostics.entries
          .where((e) => e.tag == 'notification-bridge')
          .toList();
      expect(entries, isNotEmpty);
      expect(entries.last.message, contains('delivered'));
      expect(entries.last.message, contains('targetResolved=false'));
    });

    test('logs suppressed=muted', () async {
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

    test('mentionsOnly logs targetResolved for unknown channel', () async {
      container = buildContainer(
        notificationState: const NotificationState(
          notificationPreference: NotificationPreference.mentionsOnly,
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'unknown-ch',
        messageId: 'msg-1',
        senderId: 'other-user',
        content: 'Hello',
      ));

      await Future<void>.delayed(Duration.zero);

      final entries = diagnostics.entries
          .where((e) => e.tag == 'notification-bridge')
          .toList();
      expect(entries, isNotEmpty);
      expect(entries.last.message, contains('suppressed=mentionsOnly'));
      expect(entries.last.message, contains('targetResolved=false'));
    });

    test('pinned channel resolves correctly', () async {
      container = buildContainer(
        homeState: HomeListState(
          serverScopeId: _testServerScope,
          status: HomeListStatus.success,
          pinnedChannels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: _testServerScope,
                value: 'pinned-ch',
              ),
              name: '#pinned',
            ),
          ],
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'pinned-ch',
        messageId: 'msg-1',
        senderId: 'other-user',
        senderName: 'Alice',
        content: 'Pinned message',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, hasLength(1));
      expect(showSink.shown.first['type'], 'channel');
      expect(showSink.shown.first['serverId'], _testServerId);
    });

    test('hidden DM resolves as dm', () async {
      container = buildContainer(
        homeState: HomeListState(
          serverScopeId: _testServerScope,
          status: HomeListStatus.success,
          hiddenDirectMessages: [
            HomeDirectMessageSummary(
              scopeId: DirectMessageScopeId(
                serverId: _testServerScope,
                value: 'hidden-dm',
              ),
              title: 'Hidden User',
            ),
          ],
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'hidden-dm',
        messageId: 'msg-1',
        senderId: 'other-user',
        senderName: 'Eve',
        content: 'Hidden DM',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, hasLength(1));
      expect(showSink.shown.first['type'], 'dm');
    });

    test('pinned DM resolves as dm', () async {
      container = buildContainer(
        homeState: HomeListState(
          serverScopeId: _testServerScope,
          status: HomeListStatus.success,
          pinnedDirectMessages: [
            HomeDirectMessageSummary(
              scopeId: DirectMessageScopeId(
                serverId: _testServerScope,
                value: 'pinned-dm',
              ),
              title: 'Pinned User',
            ),
          ],
        ),
      );
      container.read(realtimeNotificationBridgeProvider);

      ingress.accept(_messageNewEvent(
        channelId: 'pinned-dm',
        messageId: 'msg-1',
        senderId: 'other-user',
        senderName: 'Frank',
        content: 'Pinned DM',
      ));

      await Future<void>.delayed(Duration.zero);

      expect(showSink.shown, hasLength(1));
      expect(showSink.shown.first['type'], 'dm');
    });
  });
}

class _OverriddenNotificationStore extends NotificationStore {
  _OverriddenNotificationStore(this._initialState);

  final NotificationState _initialState;

  @override
  NotificationState build() => _initialState;
}
