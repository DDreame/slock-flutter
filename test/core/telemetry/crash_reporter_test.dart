import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';
import 'package:slock_app/core/telemetry/noop_crash_reporter.dart';

class FakeCrashReporter implements CrashReporter {
  final List<Object> capturedErrors = [];
  final List<FlutterErrorDetails> capturedFlutterErrors = [];
  final List<Breadcrumb> breadcrumbs = [];
  String? lastUserId;
  String? lastDisplayName;
  int initCount = 0;

  @override
  Future<void> init() async {
    initCount++;
  }

  @override
  void captureException(Object error,
      {StackTrace? stackTrace, Map<String, dynamic>? extra}) {
    capturedErrors.add(error);
  }

  @override
  void captureFlutterError(FlutterErrorDetails details) {
    capturedFlutterErrors.add(details);
  }

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {
    breadcrumbs.add(breadcrumb);
  }

  @override
  void setUser(String? userId, {String? displayName}) {
    lastUserId = userId;
    lastDisplayName = displayName;
  }
}

void main() {
  group('NoOpCrashReporter', () {
    test('init completes without error', () async {
      final reporter = NoOpCrashReporter();
      await reporter.init();
    });

    test('captureException does not throw', () {
      final reporter = NoOpCrashReporter();
      reporter.captureException(
        Exception('test'),
        stackTrace: StackTrace.current,
        extra: {'key': 'value'},
      );
    });

    test('captureFlutterError does not throw', () {
      final reporter = NoOpCrashReporter();
      reporter.captureFlutterError(
        FlutterErrorDetails(exception: Exception('test')),
      );
    });

    test('addBreadcrumb does not throw', () {
      final reporter = NoOpCrashReporter();
      reporter.addBreadcrumb(
        Breadcrumb(category: 'test', message: 'msg'),
      );
    });

    test('setUser does not throw', () {
      final reporter = NoOpCrashReporter();
      reporter.setUser('uid', displayName: 'Alice');
      reporter.setUser(null);
    });
  });

  group('FakeCrashReporter', () {
    test('captures exceptions', () {
      final reporter = FakeCrashReporter();
      final error = Exception('boom');
      reporter.captureException(error);
      expect(reporter.capturedErrors, [error]);
    });

    test('captures flutter errors', () {
      final reporter = FakeCrashReporter();
      final details = FlutterErrorDetails(exception: Exception('flutter'));
      reporter.captureFlutterError(details);
      expect(reporter.capturedFlutterErrors, [details]);
    });

    test('captures breadcrumbs', () {
      final reporter = FakeCrashReporter();
      final crumb = Breadcrumb(category: 'nav', message: 'pushed /home');
      reporter.addBreadcrumb(crumb);
      expect(reporter.breadcrumbs, [crumb]);
    });

    test('tracks user', () {
      final reporter = FakeCrashReporter();
      reporter.setUser('u1', displayName: 'Bob');
      expect(reporter.lastUserId, 'u1');
      expect(reporter.lastDisplayName, 'Bob');
    });
  });

  group('Breadcrumb', () {
    test('constructs with defaults', () {
      final crumb = Breadcrumb(category: 'network', message: 'GET /api');
      expect(crumb.category, 'network');
      expect(crumb.message, 'GET /api');
      expect(crumb.data, isNull);
      expect(crumb.timestamp, isA<DateTime>());
    });

    test('equality by timestamp, category, and message', () {
      final ts = DateTime(2026, 4, 19, 12, 0);
      final a = Breadcrumb(
        timestamp: ts,
        category: 'nav',
        message: 'push',
      );
      final b = Breadcrumb(
        timestamp: ts,
        category: 'nav',
        message: 'push',
        data: {'extra': true},
      );
      final c = Breadcrumb(
        timestamp: ts,
        category: 'nav',
        message: 'pop',
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });
  });
}
