import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/billing/application/billing_state.dart';
import 'package:slock_app/features/billing/application/billing_store.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';

const _serverPlanUpdatedEvent = 'server:plan-updated';

final billingRealtimeBindingProvider = Provider.autoDispose<void>((ref) {
  final serverId = ref.watch(activeServerScopeIdProvider);
  if (serverId == null) {
    return;
  }

  final ingress = ref.watch(realtimeReductionIngressProvider);
  final subscription = ingress.acceptedEvents.listen((event) {
    if (event.eventType != _serverPlanUpdatedEvent) {
      return;
    }
    if (!_belongsToCurrentServer(serverId, event)) {
      return;
    }
    if (ref.read(billingStoreProvider).status == BillingStatus.loading) {
      return;
    }

    unawaited(ref.read(billingStoreProvider.notifier).load());
  });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
}, dependencies: [activeServerScopeIdProvider]);

bool _belongsToCurrentServer(
  ServerScopeId serverId,
  RealtimeEventEnvelope event,
) {
  final serverScopePrefix = 'server:${serverId.value}';
  return event.scopeKey == serverScopePrefix ||
      event.scopeKey.startsWith('$serverScopePrefix/');
}
