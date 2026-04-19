import 'package:flutter/foundation.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';

class NoOpCrashReporter implements CrashReporter {
  @override
  Future<void> init() async {}

  @override
  void captureException(Object error,
      {StackTrace? stackTrace, Map<String, dynamic>? extra}) {}

  @override
  void captureFlutterError(FlutterErrorDetails details) {}

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {}

  @override
  void setUser(String? userId, {String? displayName}) {}
}
