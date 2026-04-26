import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart' as sentry;
import 'package:slock_app/core/telemetry/crash_reporter.dart';

class SentryCrashReporter implements CrashReporter {
  SentryCrashReporter({required this.dsn});

  final String dsn;

  @override
  Future<void> init() async {
    await sentry.SentryFlutter.init((options) {
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
    sentry.Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: extra != null
          ? (scope) {
              scope.setContexts('extra', extra);
            }
          : null,
    );
  }

  @override
  void captureFlutterError(FlutterErrorDetails details) {
    sentry.Sentry.captureException(
      details.exception,
      stackTrace: details.stack,
    );
  }

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {
    sentry.Sentry.addBreadcrumb(sentry.Breadcrumb(
      message: breadcrumb.message,
      category: breadcrumb.category,
      timestamp: breadcrumb.timestamp,
      data: breadcrumb.data,
    ));
  }

  @override
  void setUser(String? userId, {String? displayName}) {
    sentry.Sentry.configureScope((scope) {
      if (userId == null) {
        scope.setUser(null);
      } else {
        scope.setUser(sentry.SentryUser(
          id: userId,
          username: displayName,
        ));
      }
    });
  }
}
