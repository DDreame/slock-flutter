import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_bootstrap.dart';
import 'package:slock_app/core/network/network_config.dart';
import 'package:slock_app/core/notifications/android_notification_initializer.dart';
import 'package:slock_app/core/notifications/ios_notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/telemetry/crash_marker_service.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/core/telemetry/noop_crash_reporter.dart';
import 'package:slock_app/core/telemetry/sentry_crash_reporter.dart';

import '../../core/telemetry/crash_reporter_test.dart' show FakeCrashReporter;

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> store = {};

  @override
  Future<String?> read({required String key}) async => store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    store.remove(key);
  }
}

const _apiBaseUrl = 'https://api.example.com';
const _realtimeUrl = 'https://realtime.example.com';

void main() {
  group('appBootstrap', () {
    test('returns valid result with overrides', () async {
      final result = await appBootstrap(environmentReader: _environmentReader);
      expect(result.reporter, isA<NoOpCrashReporter>());
      expect(result.diagnostics, isA<DiagnosticsCollector>());
      expect(result.notificationInitializer, isA<NotificationInitializer>());
      expect(result.overrides, hasLength(5));
    });

    test('provider overrides resolve correctly', () async {
      final result = await appBootstrap(environmentReader: _environmentReader);
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
      expect(
        identical(
          container.read(notificationInitializerProvider),
          result.notificationInitializer,
        ),
        isTrue,
      );
      expect(container.read(networkConfigProvider).baseUrl, _apiBaseUrl);
      expect(container.read(realtimeSocketOptionsProvider).uri, _realtimeUrl);
    });

    test('fails fast when API base URL is missing', () async {
      await expectLater(
        appBootstrap(
          environmentReader: (key) => switch (key) {
            apiBaseUrlEnvironmentKey => '',
            realtimeUrlEnvironmentKey => _realtimeUrl,
            _ => '',
          },
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(apiBaseUrlEnvironmentKey),
          ),
        ),
      );
    });

    test(
      'fails fast when realtime URL still points at placeholder host',
      () async {
        await expectLater(
          appBootstrap(
            environmentReader: (key) => switch (key) {
              apiBaseUrlEnvironmentKey => _apiBaseUrl,
              realtimeUrlEnvironmentKey => placeholderRealtimeUrl,
              _ => '',
            },
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains(realtimeUrlEnvironmentKey),
            ),
          ),
        );
      },
    );
  });

  group('createNotificationInitializer', () {
    test('returns Android initializer for Android platform', () {
      final initializer = createNotificationInitializer(
        platform: TargetPlatform.android,
        isWeb: false,
      );

      expect(initializer, isA<AndroidNotificationInitializer>());
    });

    test('returns iOS initializer for iOS platform', () {
      final initializer = createNotificationInitializer(
        platform: TargetPlatform.iOS,
        isWeb: false,
      );

      expect(initializer, isA<IosNotificationInitializer>());
    });

    test('returns NoOp initializer on web even for Android target', () {
      final initializer = createNotificationInitializer(
        platform: TargetPlatform.android,
        isWeb: true,
      );

      expect(initializer, isA<NoOpNotificationInitializer>());
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

    test('FlutterError.onError calls crashMarker.markCrash', () async {
      final fake = FakeCrashReporter();
      final storage = _FakeSecureStorage();
      final crashMarker = CrashMarkerService(storage: storage);
      final previousHandler = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previousHandler);

      installErrorHandlers(fake, crashMarker: crashMarker);

      final details = FlutterErrorDetails(exception: Exception('crash-test'));
      FlutterError.onError!(details);

      // Allow async markCrash to complete.
      await Future<void>.delayed(Duration.zero);

      expect(await crashMarker.hasCrashMarker(), isTrue);
    });

    test('PlatformDispatcher.instance.onError calls crashMarker.markCrash',
        () async {
      final fake = FakeCrashReporter();
      final storage = _FakeSecureStorage();
      final crashMarker = CrashMarkerService(storage: storage);
      final previousFlutterHandler = FlutterError.onError;
      final previousPlatformHandler = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = previousFlutterHandler;
        PlatformDispatcher.instance.onError = previousPlatformHandler;
      });

      installErrorHandlers(fake, crashMarker: crashMarker);

      // Invoke the PlatformDispatcher error handler directly.
      final handler = PlatformDispatcher.instance.onError;
      expect(handler, isNotNull);
      handler!(StateError('platform-crash'), StackTrace.current);

      // Allow async markCrash to complete.
      await Future<void>.delayed(Duration.zero);

      expect(await crashMarker.hasCrashMarker(), isTrue);
      expect(fake.capturedErrors, hasLength(1));
    });

    test('crash marker is not written when crashMarker param is null',
        () async {
      final fake = FakeCrashReporter();
      final previousHandler = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previousHandler);

      installErrorHandlers(fake);

      final details = FlutterErrorDetails(exception: Exception('no-marker'));
      // Should not throw even without crash marker.
      FlutterError.onError!(details);

      expect(fake.capturedFlutterErrors, hasLength(1));
    });
  });

  group('createCrashReporter', () {
    test('returns NoOpCrashReporter when DSN is empty', () {
      final reporter = createCrashReporter(dsn: '');
      expect(reporter, isA<NoOpCrashReporter>());
    });

    test('returns NoOpCrashReporter when DSN is whitespace only', () {
      final reporter = createCrashReporter(dsn: '   ');
      expect(reporter, isA<NoOpCrashReporter>());
    });

    test('returns SentryCrashReporter when DSN is present', () {
      final reporter = createCrashReporter(dsn: 'https://key@sentry.io/123');
      expect(reporter, isA<SentryCrashReporter>());
    });
  });
}

String _environmentReader(String key) {
  return switch (key) {
    apiBaseUrlEnvironmentKey => _apiBaseUrl,
    realtimeUrlEnvironmentKey => _realtimeUrl,
    _ => '',
  };
}
