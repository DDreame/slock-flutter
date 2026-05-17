// ---------------------------------------------------------------------------
// #550: Crash Reporting Improvements
//
// Problem: CrashReporter infrastructure exists (Sentry + NoOp) but three
// gaps prevent full observability:
//   1. setUser() never called on auth transitions → Sentry has no user ctx
//   2. addBreadcrumb() never called for nav → no route trail in crash reports
//   3. Zone error callback inlined in main() → untestable
//
// Phase A: skip:true invariants locking the improvement contracts.
//          Test-local seams simulate auth-triggered setUser calls, a
//          GoRouter navigation observer, and an extractable zone error
//          handler. Phase B wires these into SessionStore, GoRouter, and
//          main().
//
// Invariants verified:
// INV-CRASH-USER-1: On login, CrashReporter.setUser() called with user ID
// INV-CRASH-USER-2: On logout, CrashReporter.setUser(null) clears context
// INV-CRASH-NAV-1:  GoRouter observer calls addBreadcrumb() on navigation
// INV-CRASH-ZONE-1: Zone error handler extracted as testable function
// ---------------------------------------------------------------------------
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';

// Reuse the existing FakeCrashReporter from crash_reporter_test.dart.
// It records setUser(), addBreadcrumb(), and captureException() calls.
import '../telemetry/crash_reporter_test.dart' show FakeCrashReporter;

// ---------------------------------------------------------------------------
// Test-local seams: mirror the production integration points that Phase B
// will implement.
//
// Phase B:
//   1. SessionStore calls reporter.setUser() in _hydrateAuthenticatedSession
//      and reporter.setUser(null) in logout()
//   2. A CrashBreadcrumbObserver (NavigatorObserver) is added to GoRouter
//   3. The zone error callback is extracted to a top-level function
// ---------------------------------------------------------------------------

/// Test-local seam simulating the auth→crash-reporter binding.
///
/// Phase B: this logic moves into SessionStore (or a new
/// CrashReporterAuthBinding) that listens to sessionStoreProvider
/// and calls setUser on transitions.
class _TestableAuthCrashBinding {
  _TestableAuthCrashBinding({required this.reporter});

  final CrashReporter reporter;

  /// Called after successful login/session hydration.
  void onAuthenticated({required String userId, String? displayName}) {
    reporter.setUser(userId, displayName: displayName);
  }

  /// Called on logout.
  void onLogout() {
    reporter.setUser(null);
  }
}

/// Test-local seam simulating a GoRouter navigation observer that
/// records breadcrumbs on each navigation.
///
/// Phase B: implement as a real NavigatorObserver subclass wired into
/// GoRouter's observers: parameter.
class _TestableCrashBreadcrumbObserver extends NavigatorObserver {
  _TestableCrashBreadcrumbObserver({required this.reporter});

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

/// Test-local seam: extracted zone error handler.
///
/// Phase B: extract the inline closure from main.dart's runZonedGuarded
/// into a top-level function:
///   void handleZoneError(Object error, StackTrace stack, CrashReporter reporter)
///
/// This makes the error handling testable without running the full app.
void _testableZoneErrorHandler(
  Object error,
  StackTrace stack,
  CrashReporter reporter,
) {
  reporter.captureException(error, stackTrace: stack);
}

void main() {
  // -----------------------------------------------------------------------
  // INV-CRASH-USER-1: setUser on login
  // -----------------------------------------------------------------------
  group('INV-CRASH-USER-1: setUser on authenticated session', () {
    test(
      'setUser called with userId after successful login',
      skip: true,
      () {
        final reporter = FakeCrashReporter();
        final binding = _TestableAuthCrashBinding(reporter: reporter);

        binding.onAuthenticated(userId: 'user-123');

        expect(reporter.lastUserId, 'user-123');
      },
    );

    test(
      'setUser includes displayName when available',
      skip: true,
      () {
        final reporter = FakeCrashReporter();
        final binding = _TestableAuthCrashBinding(reporter: reporter);

        binding.onAuthenticated(
          userId: 'user-456',
          displayName: 'Alice',
        );

        expect(reporter.lastUserId, 'user-456');
        expect(reporter.lastDisplayName, 'Alice');
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-CRASH-USER-2: setUser(null) on logout
  // -----------------------------------------------------------------------
  group('INV-CRASH-USER-2: setUser cleared on logout', () {
    test(
      'setUser(null) called on logout to clear Sentry user context',
      skip: true,
      () {
        final reporter = FakeCrashReporter();
        final binding = _TestableAuthCrashBinding(reporter: reporter);

        // Simulate login then logout.
        binding.onAuthenticated(userId: 'user-789');
        expect(reporter.lastUserId, 'user-789');

        binding.onLogout();
        expect(reporter.lastUserId, isNull);
      },
    );

    test(
      'displayName also cleared on logout',
      skip: true,
      () {
        final reporter = FakeCrashReporter();
        final binding = _TestableAuthCrashBinding(reporter: reporter);

        binding.onAuthenticated(
          userId: 'user-abc',
          displayName: 'Bob',
        );
        expect(reporter.lastDisplayName, 'Bob');

        binding.onLogout();
        expect(reporter.lastDisplayName, isNull);
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-CRASH-NAV-1: Navigation breadcrumbs
  // -----------------------------------------------------------------------
  group('INV-CRASH-NAV-1: navigation breadcrumb observer', () {
    test(
      'didPush records breadcrumb with route path',
      skip: true,
      () {
        final reporter = FakeCrashReporter();
        final observer = _TestableCrashBreadcrumbObserver(reporter: reporter);

        // Simulate a push navigation event.
        observer.didPush(
          _FakeRoute('/servers/s1/channels/c1'),
          null,
        );

        expect(reporter.breadcrumbs, hasLength(1));
        expect(reporter.breadcrumbs.first.category, 'navigation');
        expect(
          reporter.breadcrumbs.first.message,
          'push: /servers/s1/channels/c1',
        );
      },
    );

    test(
      'didPop records breadcrumb with popped route path',
      skip: true,
      () {
        final reporter = FakeCrashReporter();
        final observer = _TestableCrashBreadcrumbObserver(reporter: reporter);

        observer.didPop(
          _FakeRoute('/profile/u1'),
          _FakeRoute('/home'),
        );

        expect(reporter.breadcrumbs, hasLength(1));
        expect(reporter.breadcrumbs.first.message, 'pop: /profile/u1');
      },
    );

    test(
      'didReplace records breadcrumb with new route path',
      skip: true,
      () {
        final reporter = FakeCrashReporter();
        final observer = _TestableCrashBreadcrumbObserver(reporter: reporter);

        observer.didReplace(
          newRoute: _FakeRoute('/invite/token-1'),
          oldRoute: _FakeRoute('/splash'),
        );

        expect(reporter.breadcrumbs, hasLength(1));
        expect(
          reporter.breadcrumbs.first.message,
          'replace: /invite/token-1',
        );
      },
    );

    test(
      'multiple navigations accumulate breadcrumbs in order',
      skip: true,
      () {
        final reporter = FakeCrashReporter();
        final observer = _TestableCrashBreadcrumbObserver(reporter: reporter);

        observer.didPush(_FakeRoute('/home'), null);
        observer.didPush(_FakeRoute('/settings'), _FakeRoute('/home'));
        observer.didPop(_FakeRoute('/settings'), _FakeRoute('/home'));

        expect(reporter.breadcrumbs, hasLength(3));
        expect(reporter.breadcrumbs[0].message, 'push: /home');
        expect(reporter.breadcrumbs[1].message, 'push: /settings');
        expect(reporter.breadcrumbs[2].message, 'pop: /settings');
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-CRASH-ZONE-1: Extracted zone error handler
  // -----------------------------------------------------------------------
  group('INV-CRASH-ZONE-1: testable zone error handler', () {
    test(
      'zone error handler captures exception via CrashReporter',
      skip: true,
      () {
        final reporter = FakeCrashReporter();
        final error = StateError('test error');
        final stack = StackTrace.current;

        _testableZoneErrorHandler(error, stack, reporter);

        expect(reporter.capturedErrors, hasLength(1));
        expect(reporter.capturedErrors.first, error);
      },
    );

    test(
      'zone error handler works with different error types',
      skip: true,
      () {
        final reporter = FakeCrashReporter();

        _testableZoneErrorHandler(
          const FormatException('bad format'),
          StackTrace.current,
          reporter,
        );
        _testableZoneErrorHandler(
          'string error',
          StackTrace.current,
          reporter,
        );

        expect(reporter.capturedErrors, hasLength(2));
        expect(reporter.capturedErrors[0], isA<FormatException>());
        expect(reporter.capturedErrors[1], 'string error');
      },
    );
  });
}

/// Minimal fake Route for testing NavigatorObserver callbacks.
class _FakeRoute extends Route<void> {
  _FakeRoute(String name) : super(settings: RouteSettings(name: name));
}
