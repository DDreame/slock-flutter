import 'package:flutter/widgets.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';

/// [NavigatorObserver] that records navigation events as [Breadcrumb]s
/// in [CrashReporter], providing a route trail in crash reports.
///
/// Register in GoRouter's `observers:` parameter so every push, pop,
/// and replace event is captured before a crash.
class CrashBreadcrumbObserver extends NavigatorObserver {
  CrashBreadcrumbObserver({required this.reporter});

  final CrashReporter reporter;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final path = route.settings.name ?? 'unknown';
    reporter.addBreadcrumb(Breadcrumb(
      category: 'navigation',
      message: 'push: $path',
    ));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final path = route.settings.name ?? 'unknown';
    reporter.addBreadcrumb(Breadcrumb(
      category: 'navigation',
      message: 'pop: $path',
    ));
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final path = newRoute?.settings.name ?? 'unknown';
    reporter.addBreadcrumb(Breadcrumb(
      category: 'navigation',
      message: 'replace: $path',
    ));
  }
}
