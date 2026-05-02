import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/network/network_config.dart';
import 'package:slock_app/core/notifications/android_foreground_service_manager.dart';
import 'package:slock_app/core/notifications/android_notification_initializer.dart';
import 'package:slock_app/core/notifications/background_sync_manager.dart';
import 'package:slock_app/core/notifications/foreground_service_manager.dart';
import 'package:slock_app/core/notifications/ios_background_sync_manager.dart';
import 'package:slock_app/core/notifications/ios_notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/core/telemetry/crash_marker_service.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/core/telemetry/noop_crash_reporter.dart';
import 'package:slock_app/core/telemetry/sentry_crash_reporter.dart';
import 'package:slock_app/features/settings/data/base_url_settings.dart';
import 'package:slock_app/stores/session/session_store.dart';

typedef EnvironmentReader = String Function(String key);

const apiBaseUrlEnvironmentKey = 'SLOCK_API_BASE_URL';
const realtimeUrlEnvironmentKey = 'SLOCK_REALTIME_URL';
const sentryDsnEnvironmentKey = 'SENTRY_DSN';

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
  BaseUrlSettings? savedBaseUrlSettings,
}) async {
  final reporter = createCrashReporter(
    dsn: environmentReader(sentryDsnEnvironmentKey),
  );
  final diagnostics = DiagnosticsCollector();
  final notificationInitializer = createNotificationInitializer();
  final foregroundServiceManager = createForegroundServiceManager();
  final backgroundSyncManager = createBackgroundSyncManager();
  final apiBaseUrl = _resolveEndpoint(
    key: apiBaseUrlEnvironmentKey,
    envValue: environmentReader(apiBaseUrlEnvironmentKey),
    savedOverride: savedBaseUrlSettings?.apiBaseUrl,
  );
  final realtimeUrl = _resolveEndpoint(
    key: realtimeUrlEnvironmentKey,
    envValue: environmentReader(realtimeUrlEnvironmentKey),
    savedOverride: savedBaseUrlSettings?.realtimeUrl,
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
      foregroundServiceManagerProvider.overrideWithValue(
        foregroundServiceManager,
      ),
      backgroundSyncManagerProvider.overrideWithValue(
        backgroundSyncManager,
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
    sentryDsnEnvironmentKey => const String.fromEnvironment(
        sentryDsnEnvironmentKey,
      ),
    _ => '',
  };
}

@visibleForTesting
CrashReporter createCrashReporter({required String dsn}) {
  final trimmed = dsn.trim();
  if (trimmed.isEmpty) {
    return NoOpCrashReporter();
  }
  return SentryCrashReporter(dsn: trimmed);
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

/// Resolves an endpoint URL: saved user override wins over env var.
///
/// If [savedOverride] is non-empty, it is used directly (already validated
/// at save-time). Otherwise the compile-time [envValue] is validated.
String _resolveEndpoint({
  required String key,
  required String envValue,
  String? savedOverride,
}) {
  if (savedOverride != null && savedOverride.isNotEmpty) {
    return savedOverride;
  }
  return _validatedRuntimeEndpoint(key: key, rawValue: envValue);
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

ForegroundServiceManager createForegroundServiceManager({
  TargetPlatform? platform,
  bool isWeb = kIsWeb,
}) {
  final targetPlatform = platform ?? defaultTargetPlatform;
  if (!isWeb && targetPlatform == TargetPlatform.android) {
    return const AndroidForegroundServiceManager();
  }
  return const NoOpForegroundServiceManager();
}

BackgroundSyncManager createBackgroundSyncManager({
  TargetPlatform? platform,
  bool isWeb = kIsWeb,
}) {
  final targetPlatform = platform ?? defaultTargetPlatform;
  if (!isWeb && targetPlatform == TargetPlatform.iOS) {
    return const IosBackgroundSyncManager();
  }
  return const NoOpBackgroundSyncManager();
}

void installErrorHandlers(
  CrashReporter reporter, {
  DiagnosticsCollector? diagnostics,
  CrashMarkerService? crashMarker,
}) {
  FlutterError.onError = (details) {
    reporter.captureFlutterError(details);
    diagnostics?.error('crash', details.exceptionAsString());
    crashMarker?.markCrash();
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.captureException(error, stackTrace: stack);
    diagnostics?.error('error', error.toString());
    crashMarker?.markCrash();
    return true;
  };
}
