import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/android_notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/core/telemetry/noop_crash_reporter.dart';

class AppBootstrapResult {
  final CrashReporter reporter;
  final DiagnosticsCollector diagnostics;
  final NotificationInitializer notificationInitializer;
  final List<Override> overrides;

  const AppBootstrapResult({
    required this.reporter,
    required this.diagnostics,
    required this.notificationInitializer,
    required this.overrides,
  });
}

Future<AppBootstrapResult> appBootstrap() async {
  final reporter = NoOpCrashReporter();
  final diagnostics = DiagnosticsCollector();
  final notificationInitializer = createNotificationInitializer();

  await reporter.init();

  return AppBootstrapResult(
    reporter: reporter,
    diagnostics: diagnostics,
    notificationInitializer: notificationInitializer,
    overrides: [
      crashReporterProvider.overrideWithValue(reporter),
      diagnosticsCollectorProvider.overrideWithValue(diagnostics),
      notificationInitializerProvider
          .overrideWithValue(notificationInitializer),
    ],
  );
}

NotificationInitializer createNotificationInitializer({
  TargetPlatform? platform,
  bool isWeb = kIsWeb,
}) {
  final targetPlatform = platform ?? defaultTargetPlatform;
  if (!isWeb && targetPlatform == TargetPlatform.android) {
    return const AndroidNotificationInitializer();
  }
  return NoOpNotificationInitializer();
}

void installErrorHandlers(CrashReporter reporter) {
  FlutterError.onError = (details) {
    reporter.captureFlutterError(details);
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.captureException(error, stackTrace: stack);
    return true;
  };
}
