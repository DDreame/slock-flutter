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

  /// Keys whose values are replaced with `[REDACTED]` in metadata.
  static const sensitiveKeys = {
    'token',
    'password',
    'secret',
    'authorization',
    'cookie',
    'credentials',
  };

  DiagnosticsCollector({
    this.maxEntries = 500,
    this.maxRetentionAge = const Duration(hours: 24),
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

  /// Convenience method to add an info-level entry.
  void info(String tag, String message, {Map<String, dynamic>? metadata}) {
    add(DiagnosticsEntry(
      timestamp: DateTime.now(),
      level: DiagnosticsLevel.info,
      tag: tag,
      message: message,
      metadata: metadata,
    ));
  }

  /// Convenience method to add a warning-level entry.
  void warning(String tag, String message, {Map<String, dynamic>? metadata}) {
    add(DiagnosticsEntry(
      timestamp: DateTime.now(),
      level: DiagnosticsLevel.warning,
      tag: tag,
      message: message,
      metadata: metadata,
    ));
  }

  /// Convenience method to add an error-level entry.
  void error(String tag, String message, {Map<String, dynamic>? metadata}) {
    add(DiagnosticsEntry(
      timestamp: DateTime.now(),
      level: DiagnosticsLevel.error,
      tag: tag,
      message: message,
      metadata: metadata,
    ));
  }

  List<DiagnosticsEntry> get entries {
    _prune();
    return UnmodifiableListView(_buffer);
  }

  /// Returns an immutable snapshot of the current entries.
  ///
  /// The returned list is independent of the collector's internal buffer —
  /// subsequent mutations to the collector do not affect it.
  List<DiagnosticsEntry> toSnapshot() {
    _prune();
    return UnmodifiableListView(List.of(_buffer));
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
      if (sensitiveKeys.contains(key.toLowerCase())) {
        return MapEntry(key, '[REDACTED]');
      }
      return MapEntry(key, value);
    });
  }
}

final diagnosticsCollectorProvider = Provider<DiagnosticsCollector>((ref) {
  return DiagnosticsCollector();
});
