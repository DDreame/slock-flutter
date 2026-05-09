import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';
import 'package:slock_app/core/realtime/realtime_reduction_ingress.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Socket.IO event name for user coming online.
const kPresenceOnlineEvent = 'presence:online';

/// Socket.IO event name for user going offline.
const kPresenceOfflineEvent = 'presence:offline';

/// Socket.IO event name for the initial list of online users
/// sent on connection.
const kPresenceListEvent = 'presence:list';

/// Binds realtime presence events to the [PresenceStore].
///
/// Presence is global (server-scoped), not per-conversation.
/// Call [bind] to start listening, and [dispose] to stop.
class PresenceRealtimeBinding {
  PresenceRealtimeBinding({
    required this.store,
    required this.ingress,
    required this.currentUserId,
  });

  final PresenceStore store;
  final RealtimeReductionIngress ingress;
  final String? currentUserId;

  StreamSubscription<dynamic>? _subscription;

  /// Start listening for presence events.
  void bind() {
    _subscription = ingress.acceptedEvents.listen((event) {
      final payload = event.payload;
      if (payload is! Map) return;

      switch (event.eventType) {
        case kPresenceOnlineEvent:
          final userId = payload['userId'] as String?;
          if (userId == null || userId == currentUserId) return;
          store.setOnline(userId);
        case kPresenceOfflineEvent:
          final userId = payload['userId'] as String?;
          if (userId == null || userId == currentUserId) return;
          store.setOffline(userId);
        case kPresenceListEvent:
          final userIds = payload['userIds'];
          if (userIds is List) {
            store.setOnlineList(
              userIds.whereType<String>().toList(),
            );
          }
        default:
          break;
      }
    });
  }

  /// Stop listening and clear presence state.
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    store.clearAll();
  }
}

/// Creates a [PresenceRealtimeBinding] that auto-binds on creation
/// and auto-disposes when the provider is disposed.
final presenceRealtimeBindingProvider =
    Provider.autoDispose<PresenceRealtimeBinding>((ref) {
  final ingress = ref.watch(realtimeReductionIngressProvider);
  final store = ref.watch(presenceStoreProvider.notifier);
  final userId = ref.watch(
    sessionStoreProvider.select((s) => s.userId),
  );

  final binding = PresenceRealtimeBinding(
    store: store,
    ingress: ingress,
    currentUserId: userId,
  );

  binding.bind();

  ref.onDispose(() {
    binding.dispose();
  });

  return binding;
});
