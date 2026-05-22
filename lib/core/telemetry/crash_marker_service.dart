import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/storage/secure_storage.dart';

/// Storage key for the atomic crash marker payload.
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
    await _storage.write(
      key: _kCrashMarkerKey,
      value: jsonEncode(<String, Object>{
        'crashed': true,
        'timestamp': now,
      }),
    );
  }

  /// Returns `true` if a crash marker exists.
  Future<bool> hasCrashMarker() async {
    final payload = await _readMarkerPayload();
    if (payload == null) return false;
    return payload.crashed && payload.timestamp != null;
  }

  /// Returns the timestamp of the last crash, or null if no marker exists.
  Future<DateTime?> getCrashTimestamp() async {
    return (await _readMarkerPayload())?.timestamp;
  }

  Future<_CrashMarkerPayload?> _readMarkerPayload() async {
    final value = await _storage.read(key: _kCrashMarkerKey);
    if (value == null) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, Object?>) return null;
      final timestampValue = decoded['timestamp'];
      return _CrashMarkerPayload(
        crashed: decoded['crashed'] == true,
        timestamp:
            timestampValue is String ? DateTime.tryParse(timestampValue) : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Clears the crash marker and timestamp.
  Future<void> clearCrashMarker() async {
    await _storage.delete(key: _kCrashMarkerKey);
    await _storage.delete(key: _kCrashTimestampKey);
  }
}

class _CrashMarkerPayload {
  const _CrashMarkerPayload({
    required this.crashed,
    required this.timestamp,
  });

  final bool crashed;
  final DateTime? timestamp;
}

final crashMarkerServiceProvider = Provider<CrashMarkerService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return CrashMarkerService(storage: storage);
});
