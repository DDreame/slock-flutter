import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';

const _taskCreatedEvent = 'task:created';
const _taskUpdatedEvent = 'task:updated';
const _taskDeletedEvent = 'task:deleted';

/// Listens for task realtime events on the Home page and reloads
/// the home list to keep the Tasks section in sync.
final homeTasksRealtimeBindingProvider = Provider.autoDispose<void>(
  (ref) {
    final activeServerId = ref.watch(activeServerScopeIdProvider);
    if (activeServerId == null) return;

    final ingress = ref.watch(realtimeReductionIngressProvider);
    final subscription = ingress.acceptedEvents.listen((event) {
      switch (event.eventType) {
        case _taskCreatedEvent:
        case _taskUpdatedEvent:
        case _taskDeletedEvent:
          _reloadHomeList(ref);
      }
    });

    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
  },
  dependencies: [
    activeServerScopeIdProvider,
    homeListStoreProvider,
  ],
);

void _reloadHomeList(Ref ref) {
  try {
    final state = ref.read(homeListStoreProvider);
    if (state.status == HomeListStatus.loading) return;
    unawaited(ref.read(homeListStoreProvider.notifier).load());
  } catch (e, st) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: st);
  }
}
