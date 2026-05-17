import 'package:slock_app/core/core.dart';

/// Top-level zone error handler extracted from [main]'s `runZonedGuarded`.
///
/// Captures unhandled zone errors via [CrashReporter], logs to
/// [DiagnosticsCollector], and marks the crash for recovery dialog.
///
/// Extracted as a top-level function so it is unit-testable without
/// running the full app bootstrap.
void handleZoneError(
  Object error,
  StackTrace stack, {
  required CrashReporter reporter,
  required DiagnosticsCollector diagnostics,
  required CrashMarkerService crashMarker,
}) {
  reporter.captureException(error, stackTrace: stack);
  diagnostics.error('crash', error.toString());
  crashMarker.markCrash();
}
