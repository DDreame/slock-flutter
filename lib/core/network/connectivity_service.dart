import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simplified connectivity status.
enum ConnectivityStatus { online, offline }

/// Service that monitors device connectivity and exposes a simplified
/// online/offline stream.
///
/// Use [ConnectivityService.withInitialStatus] for tests with a controlled
/// stream controller.
class ConnectivityService {
  ConnectivityService._({
    required ConnectivityStatus initialStatus,
    required Stream<ConnectivityStatus> source,
  }) : _status = initialStatus {
    _subscription = source.listen((event) {
      if (event != _status) {
        _status = event;
        _controller.add(event);
      }
    });
  }

  /// Production constructor that uses the `connectivity_plus` plugin.
  ///
  /// Queries the plugin for the current connectivity state so cold starts
  /// while offline correctly reflect the offline state immediately.
  static Future<ConnectivityService> fromPlugin() async {
    final connectivity = Connectivity();
    final current = await connectivity.checkConnectivity();
    final initialStatus = mapResults(current);
    final source = connectivity.onConnectivityChanged.map(mapResults);
    return ConnectivityService._(
      initialStatus: initialStatus,
      source: source,
    );
  }

  /// Test constructor with explicit initial status and controller.
  factory ConnectivityService.withInitialStatus(
    ConnectivityStatus initialStatus, {
    required StreamController<ConnectivityStatus> controller,
  }) {
    return ConnectivityService._(
      initialStatus: initialStatus,
      source: controller.stream,
    );
  }

  ConnectivityStatus _status;
  late final StreamSubscription<ConnectivityStatus> _subscription;
  final _controller = StreamController<ConnectivityStatus>.broadcast();

  /// Whether the device currently has connectivity.
  bool get isOnline => _status == ConnectivityStatus.online;

  /// Current connectivity status.
  ConnectivityStatus get status => _status;

  /// Stream of connectivity changes (deduplicated).
  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  /// Clean up resources.
  void dispose() {
    _subscription.cancel();
    _controller.close();
  }

  /// Map connectivity_plus results to our simplified enum.
  ///
  /// Classified as online if ANY interface reports connectivity (not none).
  /// This handles mixed results (e.g. [wifi, none]) correctly (#732).
  @visibleForTesting
  static ConnectivityStatus mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      return ConnectivityStatus.offline;
    }
    if (results.any((r) => r != ConnectivityResult.none)) {
      return ConnectivityStatus.online;
    }
    return ConnectivityStatus.offline;
  }
}

/// Riverpod provider for the connectivity service.
///
/// Override in tests with [ConnectivityService.withInitialStatus].
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  // The provider creates a synchronous placeholder that will be replaced
  // by the async initializer in main.dart. In production, main.dart should
  // call `ConnectivityService.fromPlugin()` and override this provider.
  // Fallback: assume online (matches previous behavior).
  final controller = StreamController<ConnectivityStatus>.broadcast();
  final service = ConnectivityService.withInitialStatus(
    ConnectivityStatus.online,
    controller: controller,
  );
  ref.onDispose(() {
    service.dispose();
    controller.close();
  });
  return service;
});

/// Create and provide the connectivity service asynchronously.
///
/// Call in `main.dart` before `runApp()` and pass the result as a
/// provider override to `ProviderScope`.
Future<ConnectivityService> initConnectivityService() async {
  return ConnectivityService.fromPlugin();
}

// ---------------------------------------------------------------------------
// #655: Riverpod-native connectivity status provider
//
// Replaces raw StreamBuilder usage in widgets with a proper Provider that
// benefits from Riverpod lifecycle, caching, and .select() narrowing.
// ---------------------------------------------------------------------------

/// Riverpod provider exposing the current [ConnectivityStatus].
///
/// Emits the initial status synchronously and updates on connectivity changes.
/// Widgets can watch this directly instead of using raw StreamBuilder:
/// ```dart
/// final isOffline = ref.watch(connectivityStatusProvider) ==
///     ConnectivityStatus.offline;
/// ```
final connectivityStatusProvider = Provider<ConnectivityStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  // Seed with current status.
  var current = service.status;

  // Listen to the stream and self-invalidate on changes.
  final subscription = service.statusStream.listen((status) {
    current = status;
    ref.invalidateSelf();
  });
  ref.onDispose(subscription.cancel);

  return current;
});
