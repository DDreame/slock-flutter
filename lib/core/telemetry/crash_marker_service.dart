import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/storage/secure_storage.dart';

/// Storage key for the crash marker flag.
const String _kCrashMarkerKey = 'crash_marker';

/// Storage key for the crash timestamp.
const String _kCrashTimestampKey = 'crash_marker_timestamp';

/// Service for persisting and reading a crash marker.
///
/// When the app crashes (uncaught exception), a marker is written to
/// secure storage. On next startup, the splash controller checks for
/// this marker and shows a recovery dialog if present.
class CrashMarkerService {
  final SecureStorage _storage;

  CrashMarkerService({required SecureStorage storage}) : _storage = storage;

  /// Writes a crash marker with the current timestamp.
  Future<void> markCrash() async {
    final now = DateTime.now().toIso8601String();
    await _storage.write(key: _kCrashMarkerKey, value: 'true');
    await _storage.write(key: _kCrashTimestampKey, value: now);
  }

  /// Returns `true` if a crash marker exists.
  Future<bool> hasCrashMarker() async {
    final value = await _storage.read(key: _kCrashMarkerKey);
    return value == 'true';
  }

  /// Returns the timestamp of the last crash, or null if no marker exists.
  Future<DateTime?> getCrashTimestamp() async {
    final value = await _storage.read(key: _kCrashTimestampKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Clears the crash marker and timestamp.
  Future<void> clearCrashMarker() async {
    await _storage.delete(key: _kCrashMarkerKey);
    await _storage.delete(key: _kCrashTimestampKey);
  }
}

final crashMarkerServiceProvider = Provider<CrashMarkerService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return CrashMarkerService(storage: storage);
});
