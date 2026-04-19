import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/core/telemetry/noop_crash_reporter.dart';

class AppBootstrapResult {
  final CrashReporter reporter;
  final DiagnosticsCollector diagnostics;
  final List<Override> overrides;

  const AppBootstrapResult({
    required this.reporter,
    required this.diagnostics,
    required this.overrides,
  });
}

Future<AppBootstrapResult> appBootstrap() async {
  final reporter = NoOpCrashReporter();
  final diagnostics = DiagnosticsCollector();

  await reporter.init();

  return AppBootstrapResult(
    reporter: reporter,
    diagnostics: diagnostics,
    overrides: [
      crashReporterProvider.overrideWithValue(reporter),
      diagnosticsCollectorProvider.overrideWithValue(diagnostics),
    ],
  );
}
