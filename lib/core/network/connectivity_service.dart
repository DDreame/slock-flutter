import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
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
  factory ConnectivityService.fromPlugin() {
    final connectivity = Connectivity();
    final source = connectivity.onConnectivityChanged.map(_mapResults);
    // Initial status will be updated by the first stream event.
    return ConnectivityService._(
      initialStatus: ConnectivityStatus.online,
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
  static ConnectivityStatus _mapResults(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      return ConnectivityStatus.offline;
    }
    return ConnectivityStatus.online;
  }
}

/// Riverpod provider for the connectivity service.
///
/// Override in tests with [ConnectivityService.withInitialStatus].
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService.fromPlugin();
  ref.onDispose(service.dispose);
  return service;
});
