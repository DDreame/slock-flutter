import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

/// Contextual information bundled with diagnostic entries for export.
class DiagnosticContext {
  final String? appVersion;
  final String? platform;
  final String? locale;

  const DiagnosticContext({
    this.appVersion,
    this.platform,
    this.locale,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosticContext &&
          runtimeType == other.runtimeType &&
          appVersion == other.appVersion &&
          platform == other.platform &&
          locale == other.locale;

  @override
  int get hashCode => appVersion.hashCode ^ platform.hashCode ^ locale.hashCode;
}

/// An immutable bundle of diagnostic entries and optional context,
/// ready for formatting, copying, or sharing.
class DiagnosticBundle {
  final List<DiagnosticsEntry> entries;
  final DiagnosticContext? context;

  DiagnosticBundle._({
    required List<DiagnosticsEntry> entries,
    this.context,
  }) : entries = UnmodifiableListView(entries);
}

/// Service for building, formatting, and exporting diagnostic log bundles.
///
/// Handles redaction of sensitive values:
/// - Sensitive metadata keys (token, password, etc.) are redacted at
///   collector level via [DiagnosticsCollector._redact].
/// - Full URLs in metadata values are stripped to path-only in formatted text.
/// - No message body content is included in metadata.
class DiagnosticLogService {
  final DiagnosticsCollector collector;

  DiagnosticLogService({required this.collector});

  /// Builds a [DiagnosticBundle] from the current collector state.
  ///
  /// [context] — optional device/app context metadata.
  /// [maxEntries] — limits to the N most recent entries. If null, all are
  /// included.
  DiagnosticBundle buildBundle({
    DiagnosticContext? context,
    int? maxEntries,
  }) {
    final snapshot = collector.toSnapshot();
    final limited = maxEntries != null && snapshot.length > maxEntries
        ? snapshot.sublist(snapshot.length - maxEntries)
        : snapshot;

    return DiagnosticBundle._(
      entries: List.of(limited),
      context: context,
    );
  }

  /// Renders the bundle as human-readable text for copy/share/save.
  ///
  /// Applies additional output-time redaction:
  /// - Full URLs in metadata values are stripped to path-only.
  String formatText(DiagnosticBundle bundle) {
    final buffer = StringBuffer();

    // Header with context
    if (bundle.context != null) {
      buffer.writeln('=== Slock Diagnostics ===');
      if (bundle.context!.appVersion != null) {
        buffer.writeln('App Version: ${bundle.context!.appVersion}');
      }
      if (bundle.context!.platform != null) {
        buffer.writeln('Platform: ${bundle.context!.platform}');
      }
      if (bundle.context!.locale != null) {
        buffer.writeln('Locale: ${bundle.context!.locale}');
      }
      buffer.writeln();
    }

    // Entries
    for (final entry in bundle.entries) {
      final level = entry.level.name.toUpperCase();
      final time = _formatTimestamp(entry.timestamp);
      buffer.writeln('$time [$level] ${entry.tag}: ${entry.message}');

      if (entry.metadata != null && entry.metadata!.isNotEmpty) {
        for (final kv in entry.metadata!.entries) {
          final value = _redactOutputValue(kv.key, kv.value);
          buffer.writeln('  ${kv.key}: $value');
        }
      }
    }

    return buffer.toString();
  }

  /// Copies the formatted bundle text to the system clipboard.
  Future<void> copyToClipboard(DiagnosticBundle bundle) async {
    final text = formatText(bundle);
    await Clipboard.setData(ClipboardData(text: text));
  }

  static String _formatTimestamp(DateTime ts) {
    return '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}:'
        '${ts.second.toString().padLeft(2, '0')}';
  }

  /// Output-time redaction: strip full URLs to path-only.
  static String _redactOutputValue(String key, dynamic value) {
    if (value is! String) return value.toString();

    // Already redacted at collector level
    if (value == '[REDACTED]') return value;

    // Strip full URLs to path-only
    if (_isUrl(value)) {
      return _extractPath(value);
    }

    return value;
  }

  static bool _isUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static String _extractPath(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final query = uri.query.isNotEmpty ? '?${_redactQueryParams(uri)}' : '';
      return '$path$query';
    } catch (_) {
      return url;
    }
  }

  /// Redact query parameter values that look sensitive.
  static String _redactQueryParams(Uri uri) {
    if (uri.queryParameters.isEmpty) return '';
    final redacted = uri.queryParameters.entries.map((e) {
      if (DiagnosticsCollector.sensitiveKeys.contains(e.key.toLowerCase())) {
        return '${e.key}=[REDACTED]';
      }
      return '${e.key}=[REDACTED]';
    });
    return redacted.join('&');
  }
}
