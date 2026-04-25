import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/realtime/realtime_connection_state.dart';
import 'package:slock_app/core/realtime/realtime_event_envelope.dart';
import 'package:slock_app/core/realtime/realtime_reduction_ingress.dart';
import 'package:slock_app/core/realtime/realtime_service.dart';
import 'package:slock_app/core/realtime/realtime_socket_client.dart';
import 'package:slock_app/core/realtime/realtime_watchdog.dart';
import 'package:slock_app/stores/session/session_store.dart';

const placeholderRealtimeUrl = 'https://realtime.slock.invalid';

final realtimeClockProvider = Provider<Clock>((ref) => DateTime.now);

RealtimeSocketOptions buildRealtimeSocketOptions({
  required String uri,
  required String? token,
}) {
  return RealtimeSocketOptions(
    uri: uri,
    extraHeaders: {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    },
  );
}

final realtimeSocketOptionsProvider = Provider<RealtimeSocketOptions>((ref) {
  final token = ref.watch(
    sessionStoreProvider.select((sessionState) => sessionState.token),
  );

  return buildRealtimeSocketOptions(uri: placeholderRealtimeUrl, token: token);
});

final realtimeEventNormalizerProvider = Provider<RealtimeEventNormalizer>((
  ref,
) {
  return defaultRealtimeEventNormalizer;
});

final realtimeReductionIngressProvider = Provider<RealtimeReductionIngress>((
  ref,
) {
  final ingress = RealtimeReductionIngress();
  ref.onDispose(() {
    unawaited(ingress.dispose());
  });
  return ingress;
});

final realtimeSocketClientProvider = Provider<RealtimeSocketClient>((ref) {
  final options = ref.watch(realtimeSocketOptionsProvider);
  final client = SocketIoRealtimeSocketClient(options: options);
  ref.onDispose(() {
    unawaited(client.dispose());
  });
  return client;
});

final realtimeWatchdogConfigProvider = Provider<RealtimeWatchdogConfig>((ref) {
  return const RealtimeWatchdogConfig();
});

final realtimeWatchdogProvider = Provider<RealtimeWatchdog>((ref) {
  final config = ref.watch(realtimeWatchdogConfigProvider);
  return RealtimeWatchdog(config: config);
});

final realtimeWatchdogTimerFactoryProvider =
    Provider<RealtimePeriodicTimerFactory>((ref) {
      return (interval, onTick) => Timer.periodic(interval, (_) => onTick());
    });

final realtimeServiceProvider =
    NotifierProvider<RealtimeService, RealtimeConnectionState>(
      RealtimeService.new,
    );
