import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

const realtimeMessageCreatedEventType = 'message:new';

final homeRealtimeUnreadBindingProvider = Provider<void>((ref) {
  final ingress = ref.watch(realtimeReductionIngressProvider);
  final subscription = ingress.acceptedEvents.listen((event) {
    if (event.eventType != realtimeMessageCreatedEventType) {
      return;
    }

    final incoming = tryParseConversationIncomingMessage(
      event.payload,
      payloadName: 'message:new',
    );
    if (incoming == null) {
      return;
    }

    final currentUserId = ref.read(sessionStoreProvider).userId;
    if (currentUserId != null && incoming.senderId == currentUserId) {
      return;
    }

    final homeState = ref.read(homeListStoreProvider);
    if (homeState.status != HomeListStatus.success ||
        homeState.serverScopeId == null) {
      return;
    }

    final openTarget = ref.read(currentOpenConversationTargetProvider);
    if (openTarget != null &&
        openTarget.serverId == homeState.serverScopeId &&
        openTarget.conversationId == incoming.conversationId) {
      return;
    }

    final matchedChannel =
        _matchChannelScopeId(homeState, incoming.conversationId);
    final matchedDirectMessage =
        _matchDirectMessageScopeId(homeState, incoming.conversationId);

    if (matchedChannel != null && matchedDirectMessage == null) {
      ref
          .read(channelUnreadStoreProvider.notifier)
          .incrementChannelUnread(matchedChannel);
      return;
    }
    if (matchedDirectMessage != null && matchedChannel == null) {
      ref
          .read(channelUnreadStoreProvider.notifier)
          .incrementDmUnread(matchedDirectMessage);
      return;
    }

    if (matchedChannel == null && matchedDirectMessage == null) {
      final newScopeId = DirectMessageScopeId(
        serverId: homeState.serverScopeId!,
        value: incoming.conversationId,
      );
      ref.read(homeListStoreProvider.notifier).addDirectMessage(
            HomeDirectMessageSummary(
              scopeId: newScopeId,
              title: incoming.conversationId,
            ),
          );
      ref
          .read(channelUnreadStoreProvider.notifier)
          .incrementDmUnread(newScopeId);
    }
  });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});

ChannelScopeId? _matchChannelScopeId(
    HomeListState state, String conversationId) {
  for (final channel in state.channels) {
    if (channel.scopeId.value == conversationId) {
      return channel.scopeId;
    }
  }
  return null;
}

DirectMessageScopeId? _matchDirectMessageScopeId(
  HomeListState state,
  String conversationId,
) {
  for (final directMessage in state.directMessages) {
    if (directMessage.scopeId.value == conversationId) {
      return directMessage.scopeId;
    }
  }
  return null;
}
