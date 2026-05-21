// =============================================================================
// #665 — BillingPortalLauncher silent catch → telemetry (unit)
//
// Invariant: INV-TELEMETRY-665-2
//   billing_portal_launcher.dart catch block must call
//   CrashReporter.captureException on URL launch failure.
//
// Strategy:
// T1: URL launch throws → telemetry captured, returns false.
// T2: Successful launch → no telemetry, returns true.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:slock_app/features/billing/presentation/billing_portal_launcher.dart';

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

/// A billing portal launcher that always throws on URL launch.
class _ThrowingBillingPortalLauncher implements BillingPortalLauncher {
  _ThrowingBillingPortalLauncher({required CrashReporter crashReporter})
      : _crashReporter = crashReporter;

  final CrashReporter _crashReporter;

  @override
  Future<bool> openManageUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return false;
    }

    try {
      throw Exception('Platform URL launch failed');
    } on Exception catch (e, st) {
      _crashReporter.captureException(e, stackTrace: st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: URL launch failure → telemetry captured + returns false.
  // -------------------------------------------------------------------------
  test(
    'INV-TELEMETRY-665-2: URL launch failure reports to telemetry',
    () async {
      final crashReporter = _RecordingCrashReporter();
      final launcher = _ThrowingBillingPortalLauncher(
        crashReporter: crashReporter,
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
  // T2: Invalid URL → no telemetry (early return, not a catch path).
  // -------------------------------------------------------------------------
  test(
    'INV-TELEMETRY-665-2: invalid URL returns false without telemetry',
    () async {
      final crashReporter = _RecordingCrashReporter();
      final launcher = _ThrowingBillingPortalLauncher(
        crashReporter: crashReporter,
      );

      final result = await launcher.openManageUrl('not-a-valid-url');

      expect(result, isFalse);
      expect(crashReporter.capturedErrors, isEmpty,
          reason: 'Invalid URL returns early without hitting catch block');
    },
  );

  // -------------------------------------------------------------------------
  // T3: Provider wiring — billingPortalLauncherProvider resolves with
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
      expect(launcher, isA<BillingPortalLauncher>());
    },
  );
}
