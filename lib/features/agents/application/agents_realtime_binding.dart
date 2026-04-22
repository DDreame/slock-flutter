import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';

const _agentActivityEvent = 'agent:activity';
const _agentCreatedEvent = 'agent:created';
const _agentDeletedEvent = 'agent:deleted';

final agentsRealtimeBindingProvider = Provider.autoDispose<void>((ref) {
  final ingress = ref.watch(realtimeReductionIngressProvider);
  final subscription = ingress.acceptedEvents.listen((event) {
    switch (event.eventType) {
      case _agentActivityEvent:
        _handleAgentActivity(ref, event);
      case _agentCreatedEvent:
        _handleAgentCreatedOrDeleted(ref);
      case _agentDeletedEvent:
        _handleAgentCreatedOrDeleted(ref);
    }
  });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});

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
        );
  } catch (_) {}
}

void _handleAgentCreatedOrDeleted(Ref ref) {
  try {
    ref.read(agentsStoreProvider.notifier).load();
  } catch (_) {}
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
