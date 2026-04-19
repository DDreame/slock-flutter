import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/telemetry/noop_crash_reporter.dart';

abstract class CrashReporter {
  Future<void> init();

  void captureException(Object error,
      {StackTrace? stackTrace, Map<String, dynamic>? extra});

  void captureFlutterError(FlutterErrorDetails details);

  void addBreadcrumb(Breadcrumb breadcrumb);

  void setUser(String? userId, {String? displayName});
}

class Breadcrumb {
  final DateTime timestamp;
  final String category;
  final String message;
  final Map<String, dynamic>? data;

  Breadcrumb({
    DateTime? timestamp,
    required this.category,
    required this.message,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Breadcrumb &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          category == other.category &&
          message == other.message;

  @override
  int get hashCode => Object.hash(timestamp, category, message);
}

final crashReporterProvider = Provider<CrashReporter>((ref) {
  return NoOpCrashReporter();
});
