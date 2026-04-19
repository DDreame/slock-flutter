import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_bootstrap.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

import '../../core/telemetry/crash_reporter_test.dart' show FakeCrashReporter;

void main() {
  group('appBootstrap', () {
    test('returns valid result with overrides', () async {
      final result = await appBootstrap();
      expect(result.reporter, isA<CrashReporter>());
      expect(result.diagnostics, isA<DiagnosticsCollector>());
      expect(result.overrides, hasLength(2));
    });

    test('provider overrides resolve correctly', () async {
      final result = await appBootstrap();
      final container = ProviderContainer(overrides: result.overrides);
      addTearDown(container.dispose);

      expect(
        identical(container.read(crashReporterProvider), result.reporter),
        isTrue,
      );
      expect(
        identical(
          container.read(diagnosticsCollectorProvider),
          result.diagnostics,
        ),
        isTrue,
      );
    });
  });

  group('installErrorHandlers', () {
    test('FlutterError.onError routes to reporter', () {
      final fake = FakeCrashReporter();
      final previousHandler = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previousHandler);

      installErrorHandlers(fake);

      final details = FlutterErrorDetails(exception: Exception('test-error'));
      FlutterError.onError!(details);

      expect(fake.capturedFlutterErrors, hasLength(1));
      expect(
        fake.capturedFlutterErrors.first.exception.toString(),
        contains('test-error'),
      );
    });

    test('FlutterError.onError preserves presentError', () {
      final fake = FakeCrashReporter();
      final previousHandler = FlutterError.onError;
      final presented = <FlutterErrorDetails>[];
      addTearDown(() => FlutterError.onError = previousHandler);

      final previousPresent = FlutterError.presentError;
      FlutterError.presentError = (details) {
        presented.add(details);
      };
      addTearDown(() => FlutterError.presentError = previousPresent);

      installErrorHandlers(fake);

      final details = FlutterErrorDetails(exception: Exception('visible'));
      FlutterError.onError!(details);

      expect(fake.capturedFlutterErrors, hasLength(1));
      expect(presented, hasLength(1));
      expect(presented.first, same(details));
    });

    test('zone error handler routes to reporter', () {
      final fake = FakeCrashReporter();
      final error = StateError('zone-boom');
      final stack = StackTrace.current;

      fake.captureException(error, stackTrace: stack);

      expect(fake.capturedErrors, hasLength(1));
      expect(fake.capturedErrors.first, error);
    });
  });
}
