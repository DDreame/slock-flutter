import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/threads/application/thread_replies_state.dart';
import 'package:slock_app/features/threads/application/thread_replies_store.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/application/threads_inbox_state.dart';
import 'package:slock_app/features/threads/application/threads_inbox_store.dart';

const _threadUpdatedEvent = 'thread:updated';

final threadsInboxRealtimeBindingProvider = Provider.autoDispose<void>(
  (ref) {
    final serverId = ref.watch(currentThreadsServerIdProvider);
    final ingress = ref.watch(realtimeReductionIngressProvider);
    final subscription = ingress.acceptedEvents.listen((event) {
      if (event.eventType != _threadUpdatedEvent) {
        return;
      }
      if (!_matchesServer(serverId, event)) {
        return;
      }
      if (ref.read(threadsInboxStoreProvider).status ==
          ThreadsInboxStatus.loading) {
        return;
      }

      unawaited(ref.read(threadsInboxStoreProvider.notifier).load());
    });

    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
  },
  dependencies: [currentThreadsServerIdProvider, threadsInboxStoreProvider],
);

final threadRepliesRealtimeBindingProvider = Provider.autoDispose<void>(
  (ref) {
    final routeTarget = ref.watch(currentThreadRouteTargetProvider);
    final ingress = ref.watch(realtimeReductionIngressProvider);
    final subscription = ingress.acceptedEvents.listen((event) {
      if (event.eventType != _threadUpdatedEvent) {
        return;
      }

      final state = ref.read(threadRepliesStoreProvider);
      if (!_matchesThread(routeTarget, state, event)) {
        return;
      }
      if (state.status == ThreadRepliesStatus.loading) {
        return;
      }

      unawaited(ref.read(threadRepliesStoreProvider.notifier).load());
    });

    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
  },
  dependencies: [currentThreadRouteTargetProvider, threadRepliesStoreProvider],
);

bool _matchesServer(ServerScopeId serverId, RealtimeEventEnvelope event) {
  final eventServerId = _extractServerId(event);
  return eventServerId == null || eventServerId == serverId.value;
}

bool _matchesThread(
  ThreadRouteTarget routeTarget,
  ThreadRepliesState state,
  RealtimeEventEnvelope event,
) {
  if (!_matchesServer(ServerScopeId(routeTarget.serverId), event)) {
    return false;
  }

  final payload = _asMap(event.payload);
  final eventId = _optionalString(payload?['id']);
  final eventChannelId = _optionalString(payload?['channelId']) ??
      _channelIdFromScopeKey(event.scopeKey);
  final resolvedThreadChannelId =
      state.resolvedThreadChannelId ?? routeTarget.threadChannelId;

  if (resolvedThreadChannelId != null) {
    return eventChannelId == resolvedThreadChannelId ||
        eventId == resolvedThreadChannelId;
  }

  return eventId == routeTarget.parentMessageId;
}

String? _extractServerId(RealtimeEventEnvelope event) {
  final payload = _asMap(event.payload);
  final payloadServerId = _optionalString(payload?['serverId']);
  if (payloadServerId != null) {
    return payloadServerId;
  }
  final match = RegExp(r'(?:^|/)server:([^/]+)').firstMatch(event.scopeKey);
  return match?.group(1);
}

String? _channelIdFromScopeKey(String scopeKey) {
  final match = RegExp(r'(?:^|/)channel:([^/]+)').firstMatch(scopeKey);
  return match?.group(1);
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String? _optionalString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}
