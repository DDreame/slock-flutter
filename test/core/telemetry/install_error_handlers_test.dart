import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_bootstrap.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/core/telemetry/noop_crash_reporter.dart';

void main() {
  group('installErrorHandlers — diagnostics integration', () {
    late DiagnosticsCollector collector;
    late CrashReporter reporter;

    setUp(() {
      collector = DiagnosticsCollector();
      reporter = NoOpCrashReporter();
    });

    tearDown(() {
      // Reset Flutter error handler to default
      FlutterError.onError = FlutterError.presentError;
    });

    test('FlutterError writes error entry to diagnostics collector', () {
      installErrorHandlers(reporter, diagnostics: collector);

      final details = FlutterErrorDetails(
        exception: Exception('widget build failure'),
        library: 'widgets library',
        context: ErrorDescription('building TestWidget'),
      );

      // Suppress the error presentation to avoid test noise
      FlutterError.onError!(details);

      expect(collector.entries, hasLength(1));
      final entry = collector.entries.first;
      expect(entry.level, DiagnosticsLevel.error);
      expect(entry.tag, 'crash');
      expect(entry.message, contains('widget build failure'));
    });

    test('PlatformDispatcher error writes error entry to diagnostics', () {
      installErrorHandlers(reporter, diagnostics: collector);

      // Simulate platform dispatcher error callback
      final handler = PlatformDispatcher.instance.onError;
      expect(handler, isNotNull);

      final result = handler!(
        StateError('platform error'),
        StackTrace.current,
      );

      expect(result, isTrue);
      expect(collector.entries, hasLength(1));
      final entry = collector.entries.first;
      expect(entry.level, DiagnosticsLevel.error);
      expect(entry.tag, 'error');
      expect(entry.message, contains('platform error'));
    });

    test('installErrorHandlers works without diagnostics (backward compat)',
        () {
      // Should not throw when diagnostics is null
      installErrorHandlers(reporter);

      final details = FlutterErrorDetails(
        exception: Exception('no collector'),
      );
      FlutterError.onError!(details);

      // No collector, no entries to check — just ensure no crash
    });
  });
}
