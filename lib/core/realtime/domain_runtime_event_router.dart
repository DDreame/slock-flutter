import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

// ---------------------------------------------------------------------------
// Event type constants
// ---------------------------------------------------------------------------

const _channelUpdatedEvent = 'channel:updated';
const _serverMembershipRemovedEvent = 'server:membership-removed';
const _taskCreatedEvent = 'task:created';
const _taskUpdatedEvent = 'task:updated';
const _taskDeletedEvent = 'task:deleted';
const _agentActivityEvent = 'agent:activity';
const _agentCreatedEvent = 'agent:created';
const _agentDeletedEvent = 'agent:deleted';

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

/// Root-mounted, non-autoDispose provider that routes all domain realtime
/// events to the appropriate stores.
///
/// Replaces page-scoped bindings (`homeAdminRealtimeBindingProvider`,
/// `homeTasksRealtimeBindingProvider`, `agentsRealtimeBindingProvider`) that
/// only listened while their respective pages were mounted — causing missed
/// events when the user navigated away.
final domainRuntimeEventRouterProvider = Provider<void>(
  (ref) {
    final activeServerId = ref.watch(activeServerScopeIdProvider);
    final ingress = ref.watch(realtimeReductionIngressProvider);

    final subscription = ingress.acceptedEvents.listen((event) {
      switch (event.eventType) {
        // — Channel domain —
        case _channelUpdatedEvent:
          if (activeServerId != null && _targetsServer(activeServerId, event)) {
            _refreshHomeList(ref, reason: 'channelUpdated');
          }

        // — Server membership domain —
        case _serverMembershipRemovedEvent:
          if (activeServerId != null &&
              _shouldRefreshServerState(activeServerId, event)) {
            unawaited(_handleServerMembershipRemoved(ref, activeServerId));
          }

        // — Task domain —
        case _taskCreatedEvent:
        case _taskUpdatedEvent:
        case _taskDeletedEvent:
          if (activeServerId != null) {
            _refreshHomeList(ref, reason: 'taskEvent');
          }

        // — Agent domain —
        case _agentActivityEvent:
          _handleAgentActivity(ref, event);
        case _agentCreatedEvent:
        case _agentDeletedEvent:
          _handleAgentCreatedOrDeleted(ref);
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
    agentsStoreProvider,
  ],
);

// ---------------------------------------------------------------------------
// Channel / Home helpers
// ---------------------------------------------------------------------------

void _refreshHomeList(Ref ref, {required String reason}) {
  try {
    final state = ref.read(homeListStoreProvider);
    if (state.status == HomeListStatus.loading) return;
    unawaited(ref.read(homeListStoreProvider.notifier).refresh(reason: reason));
  } catch (e, st) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: st);
  }
}

// ---------------------------------------------------------------------------
// Server membership helpers
// ---------------------------------------------------------------------------

Future<void> _handleServerMembershipRemoved(
  Ref ref,
  ServerScopeId activeServerId,
) async {
  try {
    if (ref.read(serverListStoreProvider).status != ServerListStatus.loading) {
      await ref.read(serverListStoreProvider.notifier).load();
    }
  } catch (e, st) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: st);
    return;
  }

  try {
    final servers = ref.read(serverListStoreProvider).servers;
    if (!servers.any((server) => server.id == activeServerId.value)) {
      await ref.read(serverSelectionStoreProvider.notifier).clearSelection();
    }
  } catch (e, st) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: st);
  }
}

bool _shouldRefreshServerState(
  ServerScopeId activeServerId,
  RealtimeEventEnvelope event,
) {
  final eventServerId = _extractServerId(event);
  return eventServerId == null || eventServerId == activeServerId.value;
}

// ---------------------------------------------------------------------------
// Agent helpers
// ---------------------------------------------------------------------------

void _handleAgentActivity(Ref ref, RealtimeEventEnvelope event) {
  final map = _asMap(event.payload);
  if (map == null) return;
  final agentId = _optionalString(map['agentId']);
  final activity = _optionalString(map['activity']);
  if (agentId == null || activity == null) return;
  final detail = _optionalString(map['detail']);

  try {
    ref.read(agentsStoreProvider.notifier).updateActivity(
          agentId,
          activity,
          detail,
          timestamp: event.receivedAt,
        );
  } catch (_) {}
}

void _handleAgentCreatedOrDeleted(Ref ref) {
  try {
    ref.read(agentsStoreProvider.notifier).load();
  } catch (_) {}
}

// ---------------------------------------------------------------------------
// Shared parsing helpers
// ---------------------------------------------------------------------------

bool _targetsServer(ServerScopeId serverId, RealtimeEventEnvelope event) {
  final eventServerId = _extractServerId(event);
  return eventServerId == null || eventServerId == serverId.value;
}

String? _extractServerId(RealtimeEventEnvelope event) {
  final payload = _asMap(event.payload);
  final payloadServerId = _optionalString(payload?['serverId']);
  if (payloadServerId != null) return payloadServerId;
  return _serverIdFromScopeKey(event.scopeKey);
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String? _optionalString(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

String? _serverIdFromScopeKey(String scopeKey) {
  final match = RegExp(r'(?:^|/)server:([^/]+)').firstMatch(scopeKey);
  return match?.group(1);
}
