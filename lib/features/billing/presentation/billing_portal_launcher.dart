import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Signature matching [launchUrl] for testability.
typedef UrlLauncherFn = Future<bool> Function(Uri url, {LaunchMode mode});

final billingPortalLauncherProvider = Provider<BillingPortalLauncher>((ref) {
  return UrlLauncherBillingPortalLauncher(
    crashReporter: ref.read(crashReporterProvider),
  );
});

abstract class BillingPortalLauncher {
  Future<bool> openManageUrl(String url);
}

class UrlLauncherBillingPortalLauncher implements BillingPortalLauncher {
  const UrlLauncherBillingPortalLauncher({
    required CrashReporter crashReporter,
    @visibleForTesting UrlLauncherFn? launcherOverride,
  })  : _crashReporter = crashReporter,
        _launcherOverride = launcherOverride;

  final CrashReporter _crashReporter;
  final UrlLauncherFn? _launcherOverride;

  @override
  Future<bool> openManageUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return false;
    }

    try {
      final launcher = _launcherOverride ?? launchUrl;
      return await launcher(uri, mode: LaunchMode.externalApplication);
    } on Exception catch (e, st) {
      _crashReporter.captureException(e, stackTrace: st);
      return false;
    }
  }
}
