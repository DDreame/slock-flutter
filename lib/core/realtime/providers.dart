import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/network/auth_token_provider.dart';
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
  String? serverId,
}) {
  final authMap = <String, dynamic>{
    if (token != null && token.isNotEmpty) 'token': token,
    if (serverId != null && serverId.isNotEmpty) 'serverId': serverId,
  };

  return RealtimeSocketOptions(
    uri: uri,
    extraHeaders: {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    },
    auth: authMap.isNotEmpty ? authMap : null,
  );
}

final realtimeSocketOptionsProvider = Provider<RealtimeSocketOptions>((ref) {
  final token = ref.watch(
    sessionStoreProvider.select((sessionState) => sessionState.token),
  );
  final selectedServerId = ref.watch(selectedServerIdProvider);

  return buildRealtimeSocketOptions(
    uri: placeholderRealtimeUrl,
    token: token,
    serverId: selectedServerId,
  );
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

/// INV-839-BACKOFF: Random instance for jitter in exponential backoff.
/// Override in tests with `Random(seed)` for deterministic behavior.
final realtimeBackoffRandomProvider = Provider<Random>((ref) => Random());

/// INV-839-BACKOFF: Injectable sleeper for backoff delays.
/// Default uses [Future.delayed]. Tests override with a no-op to avoid
/// timing-dependent behavior in existing test suites.
typedef RealtimeBackoffSleeper = Future<void> Function(Duration delay);

final realtimeBackoffSleeperProvider = Provider<RealtimeBackoffSleeper>((ref) {
  return (delay) => Future<void>.delayed(delay);
});

/// INV-839-BACKOFF: Base delay for exponential backoff (1 second).
const realtimeBackoffBaseDelay = Duration(seconds: 1);

/// INV-839-BACKOFF: Maximum delay cap for exponential backoff (60 seconds).
const realtimeBackoffMaxDelay = Duration(seconds: 60);

final realtimeServiceProvider =
    NotifierProvider<RealtimeService, RealtimeConnectionState>(
  RealtimeService.new,
);
