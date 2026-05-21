import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:url_launcher/url_launcher.dart';

final billingPortalLauncherProvider = Provider<BillingPortalLauncher>((ref) {
  return UrlLauncherBillingPortalLauncher(
    crashReporter: ref.read(crashReporterProvider),
  );
});

abstract class BillingPortalLauncher {
  Future<bool> openManageUrl(String url);
}

class UrlLauncherBillingPortalLauncher implements BillingPortalLauncher {
  const UrlLauncherBillingPortalLauncher({required CrashReporter crashReporter})
      : _crashReporter = crashReporter;

  final CrashReporter _crashReporter;

  @override
  Future<bool> openManageUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return false;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception catch (e, st) {
      _crashReporter.captureException(e, stackTrace: st);
      return false;
    }
  }
}
