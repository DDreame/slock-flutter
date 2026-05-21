// =============================================================================
// #665 — BillingPortalLauncher silent catch → telemetry (unit)
//
// Invariant: INV-TELEMETRY-665-2
//   billing_portal_launcher.dart catch block must call
//   CrashReporter.captureException on URL launch failure.
//
// Strategy:
// T1: URL launch throws → telemetry captured, returns false (production class).
// T2: URL launch succeeds → no telemetry, returns true (production class).
// T3: Invalid URL → no telemetry, returns false (early return).
// T4: Provider wiring resolves without error.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:slock_app/features/billing/presentation/billing_portal_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _RecordingCrashReporter implements CrashReporter {
  final List<Object> capturedErrors = [];

  @override
  void captureException(Object error,
      {StackTrace? stackTrace, Map<String, dynamic>? extra}) {
    capturedErrors.add(error);
  }

  @override
  Future<void> init() async {}
  @override
  void captureFlutterError(FlutterErrorDetails details) {}
  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {}
  @override
  void setUser(String? userId, {String? displayName}) {}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: Production class — launchUrl throws → telemetry captured.
  // -------------------------------------------------------------------------
  test(
    'INV-TELEMETRY-665-2: production class reports exception to telemetry '
    'on launch failure',
    () async {
      final crashReporter = _RecordingCrashReporter();
      final launcher = UrlLauncherBillingPortalLauncher(
        crashReporter: crashReporter,
        launcherOverride: (Uri url,
            {LaunchMode mode = LaunchMode.platformDefault}) async {
          throw Exception('Platform URL launch failed');
        },
      );

      final result =
          await launcher.openManageUrl('https://example.com/billing');

      expect(result, isFalse);
      expect(crashReporter.capturedErrors, hasLength(1));
      expect(
        crashReporter.capturedErrors.first.toString(),
        contains('Platform URL launch failed'),
      );
    },
  );

  // -------------------------------------------------------------------------
  // T2: Production class — successful launch → no telemetry.
  // -------------------------------------------------------------------------
  test(
    'INV-TELEMETRY-665-2: production class returns true on successful launch',
    () async {
      final crashReporter = _RecordingCrashReporter();
      final launcher = UrlLauncherBillingPortalLauncher(
        crashReporter: crashReporter,
        launcherOverride: (Uri url,
            {LaunchMode mode = LaunchMode.platformDefault}) async {
          return true;
        },
      );

      final result =
          await launcher.openManageUrl('https://example.com/billing');

      expect(result, isTrue);
      expect(crashReporter.capturedErrors, isEmpty,
          reason: 'No telemetry on successful launch');
    },
  );

  // -------------------------------------------------------------------------
  // T3: Invalid URL → no telemetry (early return, not a catch path).
  // -------------------------------------------------------------------------
  test(
    'INV-TELEMETRY-665-2: invalid URL returns false without telemetry',
    () async {
      final crashReporter = _RecordingCrashReporter();
      final launcher = UrlLauncherBillingPortalLauncher(
        crashReporter: crashReporter,
        launcherOverride: (Uri url,
            {LaunchMode mode = LaunchMode.platformDefault}) async {
          throw Exception('should not be called');
        },
      );

      final result = await launcher.openManageUrl('not-a-valid-url');

      expect(result, isFalse);
      expect(crashReporter.capturedErrors, isEmpty,
          reason: 'Invalid URL returns early without hitting catch block');
    },
  );

  // -------------------------------------------------------------------------
  // T4: Provider wiring — billingPortalLauncherProvider resolves with
  //     crashReporter injected (no crash on read).
  // -------------------------------------------------------------------------
  test(
    'INV-TELEMETRY-665-2: provider wiring resolves without error',
    () async {
      final crashReporter = _RecordingCrashReporter();
      final container = ProviderContainer(
        overrides: [
          crashReporterProvider.overrideWithValue(crashReporter),
        ],
      );
      addTearDown(container.dispose);

      final launcher = container.read(billingPortalLauncherProvider);
      expect(launcher, isA<UrlLauncherBillingPortalLauncher>());
    },
  );
}
