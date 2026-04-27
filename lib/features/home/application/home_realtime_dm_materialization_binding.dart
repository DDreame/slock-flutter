import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:slock_app/features/conversation/data/conversation_identity_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';

const realtimeDmNewEventType = 'dm:new';

final homeRealtimeDmMaterializationBindingProvider = Provider<void>((ref) {
  final pendingChannelIds = <String>[];

  final ingress = ref.watch(realtimeReductionIngressProvider);
  final subscription = ingress.acceptedEvents.listen((event) async {
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

    ref.read(realtimeSocketClientProvider).emit('join:channel', channelId);

    final homeState = ref.read(homeListStoreProvider);
    if (homeState.status != HomeListStatus.success ||
        homeState.serverScopeId == null) {
      pendingChannelIds.add(channelId);
      return;
    }

    try {
      await _materializeDm(ref, homeState.serverScopeId!, channelId, map);
    } catch (e, st) {
      ref.read(crashReporterProvider).captureException(e, stackTrace: st);
    }
  });

  ref.listen(homeListStoreProvider, (previous, next) {
    if (next.status != HomeListStatus.success ||
        next.serverScopeId == null ||
        pendingChannelIds.isEmpty) {
      return;
    }
    final toReplay = List<String>.of(pendingChannelIds);
    pendingChannelIds.clear();
    for (final channelId in toReplay) {
      unawaited(() async {
        try {
          await _materializeDm(ref, next.serverScopeId!, channelId, null);
        } catch (e, st) {
          ref.read(crashReporterProvider).captureException(e, stackTrace: st);
        }
      }());
    }
  });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});

Future<void> _materializeDm(
  Ref ref,
  ServerScopeId serverId,
  String channelId,
  Map<String, dynamic>? eventMap,
) async {
  final scopeId = DirectMessageScopeId(
    serverId: serverId,
    value: channelId,
  );

  final title = eventMap != null
      ? (resolveDirectMessageTitle(eventMap) ?? channelId)
      : channelId;

  final summary =
      await ref.read(homeRepositoryProvider).persistDirectMessageSummary(
            HomeDirectMessageSummary(scopeId: scopeId, title: title),
          );

  ref.read(homeListStoreProvider.notifier).addDirectMessage(summary);
}
