import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/network/network_config.dart';
import 'package:slock_app/core/notifications/android_notification_initializer.dart';
import 'package:slock_app/core/notifications/ios_notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/core/telemetry/noop_crash_reporter.dart';
import 'package:slock_app/stores/session/session_store.dart';

typedef EnvironmentReader = String Function(String key);

const apiBaseUrlEnvironmentKey = 'SLOCK_API_BASE_URL';
const realtimeUrlEnvironmentKey = 'SLOCK_REALTIME_URL';

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

Future<AppBootstrapResult> appBootstrap({
  EnvironmentReader environmentReader = _readCompileTimeEnvironment,
}) async {
  final reporter = NoOpCrashReporter();
  final diagnostics = DiagnosticsCollector();
  final notificationInitializer = createNotificationInitializer();
  final apiBaseUrl = _validatedRuntimeEndpoint(
    key: apiBaseUrlEnvironmentKey,
    rawValue: environmentReader(apiBaseUrlEnvironmentKey),
  );
  final realtimeUrl = _validatedRuntimeEndpoint(
    key: realtimeUrlEnvironmentKey,
    rawValue: environmentReader(realtimeUrlEnvironmentKey),
  );

  await reporter.init();

  return AppBootstrapResult(
    reporter: reporter,
    diagnostics: diagnostics,
    notificationInitializer: notificationInitializer,
    overrides: [
      crashReporterProvider.overrideWithValue(reporter),
      diagnosticsCollectorProvider.overrideWithValue(diagnostics),
      notificationInitializerProvider.overrideWithValue(
        notificationInitializer,
      ),
      networkConfigProvider.overrideWithValue(
        NetworkConfig(baseUrl: apiBaseUrl),
      ),
      realtimeSocketOptionsProvider.overrideWith((ref) {
        final token = ref.watch(
          sessionStoreProvider.select((sessionState) => sessionState.token),
        );
        return buildRealtimeSocketOptions(uri: realtimeUrl, token: token);
      }),
    ],
  );
}

String _readCompileTimeEnvironment(String key) {
  return switch (key) {
    apiBaseUrlEnvironmentKey => const String.fromEnvironment(
        apiBaseUrlEnvironmentKey,
      ),
    realtimeUrlEnvironmentKey => const String.fromEnvironment(
        realtimeUrlEnvironmentKey,
      ),
    _ => '',
  };
}

String _validatedRuntimeEndpoint({
  required String key,
  required String rawValue,
}) {
  final value = rawValue.trim();
  if (value.isEmpty) {
    throw StateError('Missing required dart-define: $key');
  }
  if (value.contains('.invalid')) {
    throw StateError('Invalid runtime endpoint for $key: $value');
  }
  return value;
}

NotificationInitializer createNotificationInitializer({
  TargetPlatform? platform,
  bool isWeb = kIsWeb,
}) {
  final targetPlatform = platform ?? defaultTargetPlatform;
  if (!isWeb && targetPlatform == TargetPlatform.android) {
    return const AndroidNotificationInitializer();
  }
  if (!isWeb && targetPlatform == TargetPlatform.iOS) {
    return const IosNotificationInitializer();
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
