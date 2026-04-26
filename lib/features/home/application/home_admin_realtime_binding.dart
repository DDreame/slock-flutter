import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

const _channelUpdatedEvent = 'channel:updated';
const _serverMembershipRemovedEvent = 'server:membership-removed';

final homeAdminRealtimeBindingProvider = Provider.autoDispose<void>(
  (ref) {
    final activeServerId = ref.watch(activeServerScopeIdProvider);
    if (activeServerId == null) {
      return;
    }

    final ingress = ref.watch(realtimeReductionIngressProvider);
    final subscription = ingress.acceptedEvents.listen((event) {
      switch (event.eventType) {
        case _channelUpdatedEvent:
          if (_targetsServer(activeServerId, event)) {
            _reloadHomeList(ref);
          }
          break;
        case _serverMembershipRemovedEvent:
          if (_shouldRefreshServerState(activeServerId, event)) {
            unawaited(_reloadServerState(ref, activeServerId));
          }
          break;
        default:
          break;
      }
    });

    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
  },
  dependencies: [
    activeServerScopeIdProvider,
    homeListStoreProvider,
    serverListStoreProvider,
    serverSelectionStoreProvider,
  ],
);

void _reloadHomeList(Ref ref) {
  try {
    final state = ref.read(homeListStoreProvider);
    if (state.status == HomeListStatus.loading) {
      return;
    }
    unawaited(ref.read(homeListStoreProvider.notifier).load());
  } catch (_) {}
}

Future<void> _reloadServerState(Ref ref, ServerScopeId activeServerId) async {
  try {
    if (ref.read(serverListStoreProvider).status != ServerListStatus.loading) {
      await ref.read(serverListStoreProvider.notifier).load();
    }
  } catch (_) {
    return;
  }

  try {
    final servers = ref.read(serverListStoreProvider).servers;
    if (!servers.any((server) => server.id == activeServerId.value)) {
      await ref.read(serverSelectionStoreProvider.notifier).clearSelection();
    }
  } catch (_) {}
}

bool _shouldRefreshServerState(
  ServerScopeId activeServerId,
  RealtimeEventEnvelope event,
) {
  final eventServerId = _extractServerId(event);
  return eventServerId == null || eventServerId == activeServerId.value;
}

bool _targetsServer(ServerScopeId serverId, RealtimeEventEnvelope event) {
  final eventServerId = _extractServerId(event);
  return eventServerId == null || eventServerId == serverId.value;
}

String? _extractServerId(RealtimeEventEnvelope event) {
  final payload = _asMap(event.payload);
  final payloadServerId = _optionalString(payload?['serverId']);
  if (payloadServerId != null) {
    return payloadServerId;
  }
  return _serverIdFromScopeKey(event.scopeKey);
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

String? _serverIdFromScopeKey(String scopeKey) {
  final match = RegExp(r'(?:^|/)server:([^/]+)').firstMatch(scopeKey);
  return match?.group(1);
}
