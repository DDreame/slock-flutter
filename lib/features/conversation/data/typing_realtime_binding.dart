import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/core/realtime/realtime_reduction_ingress.dart';
import 'package:slock_app/core/realtime/realtime_socket_client.dart';
import 'package:slock_app/features/conversation/application/typing_indicator_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Socket.IO event name for typing start notifications.
const kTypingStartEvent = 'typing:start';

/// Binds realtime typing events to the [TypingIndicatorStore] for a
/// specific conversation scope.
///
/// Call [bind] to start listening, and [dispose] to stop.
/// Also provides [emitTyping] to send throttled typing events to the
/// server when the local user is composing.
class TypingRealtimeBinding {
  TypingRealtimeBinding({
    required this.scopeKey,
    required this.store,
    required this.ingress,
    required this.socketClient,
    required this.currentUserId,
  });

  final String scopeKey;
  final TypingIndicatorStore store;
  final RealtimeReductionIngress ingress;
  final RealtimeSocketClient socketClient;
  final String? currentUserId;

  StreamSubscription<dynamic>? _subscription;

  /// Start listening for typing events matching [scopeKey].
  void bind() {
    _subscription = ingress.acceptedEvents.listen((event) {
      if (event.eventType != kTypingStartEvent) return;

      final payload = event.payload;
      if (payload is! Map) return;

      // Only process events for our conversation scope.
      final eventScope = payload['scopeKey'];
      if (eventScope != scopeKey) return;

      final userId = payload['userId'] as String?;
      final displayName = payload['displayName'] as String?;

      // Ignore typing events from the current user.
      if (userId == null || userId == currentUserId) return;

      store.addTyper(
        userId: userId,
        displayName: displayName ?? userId,
      );
    });
  }

  /// Emit a typing event to the server if the debounce cooldown allows.
  void emitTyping() {
    if (store.shouldEmitTyping()) {
      socketClient.emit(kTypingStartEvent, {
        'scopeKey': scopeKey,
      });
    }
  }

  /// Stop listening and clear typing state.
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    store.clearAll();
  }
}

/// Creates a [TypingRealtimeBinding] for the given [scopeKey].
///
/// Usage in a widget or store:
/// ```dart
/// final binding = ref.read(typingRealtimeBindingProvider(scopeKey));
/// binding.bind();
/// // ... on dispose: binding.dispose();
/// ```
final typingRealtimeBindingProvider =
    Provider.autoDispose.family<TypingRealtimeBinding, String>((
  ref,
  scopeKey,
) {
  final ingress = ref.watch(realtimeReductionIngressProvider);
  final socketClient = ref.watch(realtimeSocketClientProvider);
  final store = ref.watch(typingIndicatorStoreProvider.notifier);
  final userId = ref.watch(
    sessionStoreProvider.select((s) => s.userId),
  );

  final binding = TypingRealtimeBinding(
    scopeKey: scopeKey,
    store: store,
    ingress: ingress,
    socketClient: socketClient,
    currentUserId: userId,
  );

  binding.bind();

  ref.onDispose(() {
    binding.dispose();
  });

  return binding;
});
