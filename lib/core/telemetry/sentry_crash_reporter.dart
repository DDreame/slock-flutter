import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';

class SentryCrashReporter implements CrashReporter {
  SentryCrashReporter({required this.dsn});

  final String dsn;

  @override
  Future<void> init() async {
    await SentryFlutter.init((options) {
      options.dsn = dsn;
      options.tracesSampleRate = 0;
      options.attachStacktrace = true;
    });
  }

  @override
  void captureException(
    Object error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: extra != null
          ? (scope) {
              for (final entry in extra.entries) {
                scope.setExtra(entry.key, entry.value);
              }
            }
          : null,
    );
  }

  @override
  void captureFlutterError(FlutterErrorDetails details) {
    Sentry.captureException(
      details.exception,
      stackTrace: details.stack,
    );
  }

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {
    Sentry.addBreadcrumb(SentryBreadcrumb(
      message: breadcrumb.message,
      category: breadcrumb.category,
      timestamp: breadcrumb.timestamp,
      data: breadcrumb.data,
    ));
  }

  @override
  void setUser(String? userId, {String? displayName}) {
    Sentry.configureScope((scope) {
      if (userId == null) {
        scope.setUser(null);
      } else {
        scope.setUser(SentryUser(
          id: userId,
          username: displayName,
        ));
      }
    });
  }
}
