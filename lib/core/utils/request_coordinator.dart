/// Per-reason request deduplication coordinator.
///
/// When multiple callers trigger the same logical operation (e.g. pull-to-refresh,
/// reconnect, app-resume), the coordinator ensures only one network request
/// is in-flight per reason key. Subsequent callers for the same reason receive
/// the result of the already-running request.
///
/// Different reason keys run independently and concurrently.
///
/// Usage:
/// ```dart
/// final coordinator = RequestCoordinator();
/// final data = await coordinator.coordinate(
///   'pullToRefresh',
///   () => repository.fetchData(),
/// );
/// ```
class RequestCoordinator {
  final Map<String, Future<Object?>> _inFlight = {};
  bool _disposed = false;

  /// Execute [action] under the given [reason] key.
  ///
  /// If a request with the same [reason] is already in-flight, the existing
  /// future is returned and [action] is not called.
  ///
  /// After the future completes (success or error), the reason key is cleared
  /// so subsequent calls will execute a new action.
  Future<T> coordinate<T>(String reason, Future<T> Function() action) {
    if (_disposed) {
      throw StateError('RequestCoordinator has been disposed');
    }

    final existing = _inFlight[reason];
    if (existing != null) {
      return existing.then((value) => value as T);
    }

    final future = action().whenComplete(() {
      _inFlight.remove(reason);
    });

    _inFlight[reason] = future;
    return future;
  }

  /// Whether a request with the given [reason] is currently in-flight.
  bool isInFlight(String reason) => _inFlight.containsKey(reason);

  /// Cancel tracking of all in-flight requests.
  ///
  /// This does not cancel the underlying futures — it only clears the
  /// coordinator's tracking state so new requests can be started.
  void cancelAll() {
    _inFlight.clear();
  }

  /// Dispose the coordinator. After disposal, [coordinate] throws
  /// [StateError].
  void dispose() {
    _disposed = true;
    _inFlight.clear();
  }
}
