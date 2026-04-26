import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

const _serverMembershipRemovedEvent = 'server:membership-removed';

final membersRealtimeBindingProvider = Provider.autoDispose<void>(
  (ref) {
    final serverId = ref.watch(currentMembersServerIdProvider);
    final ingress = ref.watch(realtimeReductionIngressProvider);
    final subscription = ingress.acceptedEvents.listen((event) {
      if (event.eventType != _serverMembershipRemovedEvent) {
        return;
      }
      if (!_matchesServer(serverId, event)) {
        return;
      }

      unawaited(_handleMembershipRemoved(ref, serverId));
    });

    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
  },
  dependencies: [
    currentMembersServerIdProvider,
    memberListStoreProvider,
    serverListStoreProvider,
    serverSelectionStoreProvider,
  ],
);

Future<void> _handleMembershipRemoved(Ref ref, ServerScopeId serverId) async {
  try {
    if (ref.read(memberListStoreProvider).status != MemberListStatus.loading) {
      await ref.read(memberListStoreProvider.notifier).load();
    }
  } catch (_) {}

  try {
    if (ref.read(serverListStoreProvider).status != ServerListStatus.loading) {
      await ref.read(serverListStoreProvider.notifier).load();
    }
  } catch (_) {
    return;
  }

  try {
    final servers = ref.read(serverListStoreProvider).servers;
    if (!servers.any((server) => server.id == serverId.value)) {
      await ref.read(serverSelectionStoreProvider.notifier).clearSelection();
    }
  } catch (_) {}
}

bool _matchesServer(ServerScopeId serverId, RealtimeEventEnvelope event) {
  final eventServerId = _extractServerId(event);
  return eventServerId == null || eventServerId == serverId.value;
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
