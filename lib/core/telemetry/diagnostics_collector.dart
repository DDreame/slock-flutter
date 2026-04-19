import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DiagnosticsLevel { info, warning, error }

class DiagnosticsEntry {
  final DateTime timestamp;
  final DiagnosticsLevel level;
  final String tag;
  final String message;
  final Map<String, dynamic>? metadata;

  const DiagnosticsEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.metadata,
  });
}

class DiagnosticsCollector {
  final int maxEntries;
  final Duration maxRetentionAge;
  final List<DiagnosticsEntry> _buffer = [];

  static const _sensitiveKeys = {
    'token',
    'password',
    'secret',
    'authorization',
    'cookie',
    'credentials',
  };

  DiagnosticsCollector({
    this.maxEntries = 200,
    this.maxRetentionAge = const Duration(minutes: 30),
  });

  void add(DiagnosticsEntry entry) {
    final redacted = entry.metadata != null
        ? DiagnosticsEntry(
            timestamp: entry.timestamp,
            level: entry.level,
            tag: entry.tag,
            message: entry.message,
            metadata: _redact(entry.metadata!),
          )
        : entry;

    _buffer.add(redacted);
    _prune();
  }

  List<DiagnosticsEntry> get entries {
    _prune();
    return UnmodifiableListView(_buffer);
  }

  void clear() {
    _buffer.clear();
  }

  void _prune() {
    final now = DateTime.now();
    _buffer.removeWhere(
      (e) => now.difference(e.timestamp) > maxRetentionAge,
    );
    while (_buffer.length > maxEntries) {
      _buffer.removeAt(0);
    }
  }

  static Map<String, dynamic> _redact(Map<String, dynamic> metadata) {
    return metadata.map((key, value) {
      if (_sensitiveKeys.contains(key.toLowerCase())) {
        return MapEntry(key, '[REDACTED]');
      }
      return MapEntry(key, value);
    });
  }
}

final diagnosticsCollectorProvider = Provider<DiagnosticsCollector>((ref) {
  return DiagnosticsCollector();
});
