import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_member_state.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

const _channelUpdatedEvent = 'channel:updated';
const _channelMembersUpdatedEvent = 'channel:members-updated';

final channelPageRealtimeBindingProvider = Provider.autoDispose<void>(
  (ref) {
    final target = ref.watch(currentConversationDetailTargetProvider);
    if (target.surface != ConversationSurface.channel) {
      return;
    }

    final ingress = ref.watch(realtimeReductionIngressProvider);
    final subscription = ingress.acceptedEvents.listen((event) {
      if (event.eventType != _channelUpdatedEvent) {
        return;
      }
      if (!_matchesChannel(target.serverId, target.conversationId, event)) {
        return;
      }
      if (ref.read(conversationDetailStoreProvider).status ==
          ConversationDetailStatus.loading) {
        return;
      }

      unawaited(ref.read(conversationDetailStoreProvider.notifier).load());
    });

    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
  },
  dependencies: [
    currentConversationDetailTargetProvider,
    conversationDetailStoreProvider,
  ],
);

final channelMembersRealtimeBindingProvider = Provider.autoDispose<void>(
  (ref) {
    final serverId = ref.watch(currentChannelMemberServerIdProvider);
    final channelId = ref.watch(currentChannelMemberChannelIdProvider);
    final ingress = ref.watch(realtimeReductionIngressProvider);
    final subscription = ingress.acceptedEvents.listen((event) {
      if (event.eventType != _channelMembersUpdatedEvent) {
        return;
      }
      if (!_matchesChannel(serverId, channelId, event)) {
        return;
      }
      if (ref.read(channelMemberStoreProvider).status ==
          ChannelMemberStatus.loading) {
        return;
      }

      unawaited(ref.read(channelMemberStoreProvider.notifier).load());
    });

    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
  },
  dependencies: [
    currentChannelMemberServerIdProvider,
    currentChannelMemberChannelIdProvider,
    channelMemberStoreProvider,
  ],
);

bool _matchesChannel(
  ServerScopeId serverId,
  String channelId,
  RealtimeEventEnvelope event,
) {
  final eventServerId = _extractServerId(event);
  if (eventServerId != null && eventServerId != serverId.value) {
    return false;
  }

  final eventChannelId = _extractChannelId(event);
  return eventChannelId == null || eventChannelId == channelId;
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

String? _extractChannelId(RealtimeEventEnvelope event) {
  final payload = _asMap(event.payload);
  final payloadChannelId =
      _optionalString(payload?['channelId']) ?? _optionalString(payload?['id']);
  if (payloadChannelId != null) {
    return payloadChannelId;
  }
  final match = RegExp(r'(?:^|/)channel:([^/]+)').firstMatch(event.scopeKey);
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
