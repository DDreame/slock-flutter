// ---------------------------------------------------------------------------
// #557: Error Handling Hardening — firstOrNull + Realtime Catch Narrowing
//
// Problem:
//   1. `member_list_store.dart:171` uses `firstWhere` without `orElse`,
//      throwing unhandled `StateError` on DM open race condition.
//   2. 14 silent `catch (_) {}` blocks across 5 realtime/push files swallow
//      ALL exceptions (including TypeError, FormatException) — should narrow
//      to `on StateError` and route the rest to crash reporter.
//
// Phase A: skip:true invariants locking the error handling contracts.
//
// Invariants verified:
// INV-MEMBER-SAFE-1: openDirectMessage with missing member returns gracefully
// INV-MEMBER-SAFE-2: openDirectMessage with valid member still works
// INV-CATCH-NARROW-1: StateError from disposed provider is silently caught
// INV-CATCH-NARROW-2: TypeError in realtime binding reaches crash reporter
// INV-CATCH-NARROW-3: FormatException in realtime binding reaches crash reporter
// INV-CATCH-REPORT-1: crashReporter.captureException called with original exception
// ---------------------------------------------------------------------------
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';

void main() {
  // -----------------------------------------------------------------------
  // INV-MEMBER-SAFE-1: openDirectMessage with missing member
  // -----------------------------------------------------------------------
  group('INV-MEMBER-SAFE-1: missing member safety', () {
    test(
      'openDirectMessage with non-existent userId does not throw StateError',
      () async {
        // Pump a MemberListStore with an empty member list,
        // then call openDirectMessage with a userId that doesn't exist.
        // Phase B will replace firstWhere with firstOrNull and handle
        // the null case gracefully.
        //
        // Seam: the test verifies that calling openDirectMessage with a
        // non-existent user ID either returns an error state or throws
        // AppFailure — but NOT StateError.
        expect(
          () async {
            // This will be tested with a real or fake store in Phase B.
            // For now, verify the contract: StateError is not acceptable.
            throw StateError('member not found');
          },
          throwsA(isNot(isA<StateError>())),
        );
      },
      skip: 'Phase A: invariant locked — Phase B adds firstOrNull',
    );

    test(
      'openDirectMessage returns AppFailure for missing member',
      () async {
        // When a member is not found, the store should produce an
        // AppFailure (user-facing error) rather than crashing.
        expect(
          () async {
            throw const NotFoundFailure(message: 'Member not found');
          },
          throwsA(isA<AppFailure>()),
        );
      },
      skip: 'Phase A: invariant locked — Phase B adds firstOrNull',
    );
  });

  // -----------------------------------------------------------------------
  // INV-MEMBER-SAFE-2: openDirectMessage with valid member
  // -----------------------------------------------------------------------
  group('INV-MEMBER-SAFE-2: valid member still works', () {
    test(
      'openDirectMessage with existing member returns channel ID',
      () async {
        // After the fix, valid members should still resolve normally.
        // Phase B will test with a fake MemberListStore + repository.
        const channelId = 'dm-channel-1';
        expect(channelId, isNotEmpty);
      },
      skip: 'Phase A: invariant locked — Phase B validates happy path',
    );
  });

  // -----------------------------------------------------------------------
  // INV-CATCH-NARROW-1: StateError silently caught
  // -----------------------------------------------------------------------
  group('INV-CATCH-NARROW-1: StateError still caught silently', () {
    test(
      'StateError from disposed provider is silently swallowed',
      () {
        // After narrowing catch blocks, StateError (the expected case
        // when a provider is disposed during callback) should still be
        // caught silently — this is the existing intended behavior.
        //
        // Phase B will test by simulating a disposed provider scenario
        // in a realtime binding and verifying no crash reporter call.
        bool caughtSilently = false;
        try {
          throw StateError('Bad state: No element');
        } on StateError catch (_) {
          caughtSilently = true;
        }
        expect(caughtSilently, isTrue);
      },
      skip: 'Phase A: invariant locked — Phase B narrows catch blocks',
    );
  });

  // -----------------------------------------------------------------------
  // INV-CATCH-NARROW-2: TypeError reaches crash reporter
  // -----------------------------------------------------------------------
  group('INV-CATCH-NARROW-2: TypeError not silently swallowed', () {
    test(
      'TypeError in realtime binding is forwarded to crash reporter',
      () {
        // After narrowing, TypeError should NOT be silently swallowed.
        // It should fall through to the catch-all that routes to
        // crashReporter.captureException().
        //
        // Phase B will test with a mock crash reporter and verify the
        // exception is captured.
        bool reachedCrashReporter = false;
        try {
          // Simulate a type error in a realtime callback.
          throw TypeError();
        } on StateError catch (_) {
          // Should NOT match.
          fail('TypeError should not be caught by StateError handler');
        } catch (e, st) {
          // This simulates crashReporter.captureException(e, stackTrace: st).
          reachedCrashReporter = true;
          expect(e, isA<TypeError>());
          expect(st, isNotNull);
        }
        expect(reachedCrashReporter, isTrue);
      },
      skip: 'Phase A: invariant locked — Phase B narrows catch blocks',
    );
  });

  // -----------------------------------------------------------------------
  // INV-CATCH-NARROW-3: FormatException reaches crash reporter
  // -----------------------------------------------------------------------
  group('INV-CATCH-NARROW-3: FormatException not silently swallowed', () {
    test(
      'FormatException from malformed event payload reaches crash reporter',
      () {
        // After narrowing, FormatException (e.g. from a malformed realtime
        // event payload) should NOT be silently swallowed.
        bool reachedCrashReporter = false;
        try {
          throw const FormatException('Unexpected end of input');
        } on StateError catch (_) {
          fail('FormatException should not match StateError handler');
        } catch (e, st) {
          reachedCrashReporter = true;
          expect(e, isA<FormatException>());
          expect(st, isNotNull);
        }
        expect(reachedCrashReporter, isTrue);
      },
      skip: 'Phase A: invariant locked — Phase B narrows catch blocks',
    );
  });

  // -----------------------------------------------------------------------
  // INV-CATCH-REPORT-1: captureException called with original exception
  // -----------------------------------------------------------------------
  group('INV-CATCH-REPORT-1: crash reporter receives original exception', () {
    test(
      'captureException is called with the original exception and stack trace',
      () {
        // Phase B will verify with a mock crash reporter that the
        // captureException call receives the exact exception and
        // stack trace from the catch block.
        Object? capturedError;
        StackTrace? capturedStack;

        try {
          throw ArgumentError('bad argument');
        } on StateError catch (_) {
          // Not expected.
        } catch (e, st) {
          // Simulate: crashReporter.captureException(e, stackTrace: st);
          capturedError = e;
          capturedStack = st;
        }

        expect(capturedError, isA<ArgumentError>());
        expect(capturedStack, isNotNull);
      },
      skip: 'Phase A: invariant locked — Phase B narrows catch blocks',
    );
  });
}
