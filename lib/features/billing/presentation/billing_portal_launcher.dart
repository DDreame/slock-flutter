import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final billingPortalLauncherProvider = Provider<BillingPortalLauncher>((ref) {
  return const UrlLauncherBillingPortalLauncher();
});

abstract class BillingPortalLauncher {
  Future<bool> openManageUrl(String url);
}

class UrlLauncherBillingPortalLauncher implements BillingPortalLauncher {
  const UrlLauncherBillingPortalLauncher();

  @override
  Future<bool> openManageUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return false;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
