import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

const realtimeDmNewEventType = 'dm:new';

final homeRealtimeDmMaterializationBindingProvider = Provider<void>((ref) {
  final ingress = ref.watch(realtimeReductionIngressProvider);
  final subscription = ingress.acceptedEvents.listen((event) {
    if (event.eventType != realtimeDmNewEventType) {
      return;
    }

    final payload = event.payload;
    if (payload == null) return;

    final map = payload is Map<String, dynamic>
        ? payload
        : (payload is Map ? Map<String, dynamic>.from(payload) : null);
    if (map == null) return;

    final channelId = readOptionalConversationPayloadString(map['channelId']);
    if (channelId == null) return;

    final homeState = ref.read(homeListStoreProvider);
    if (homeState.status != HomeListStatus.success ||
        homeState.serverScopeId == null) {
      return;
    }

    final scopeId = DirectMessageScopeId(
      serverId: homeState.serverScopeId!,
      value: channelId,
    );

    final title = readOptionalConversationPayloadString(map['displayName']) ??
        readOptionalConversationPayloadString(map['name']) ??
        readOptionalConversationPayloadString(map['title']) ??
        channelId;

    ref.read(homeListStoreProvider.notifier).addDirectMessage(
          HomeDirectMessageSummary(scopeId: scopeId, title: title),
        );

    ref.read(realtimeSocketClientProvider).emit('join:channel', channelId);
  });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});
