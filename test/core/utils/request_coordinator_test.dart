import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/utils/request_coordinator.dart';

void main() {
  group('RequestCoordinator', () {
    late RequestCoordinator coordinator;

    setUp(() {
      coordinator = RequestCoordinator();
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('executes action and returns result', () async {
      final result = await coordinator.coordinate(
        'initialLoad',
        () async => 42,
      );

      expect(result, 42);
    });

    test('deduplicates concurrent same-reason requests', () async {
      var callCount = 0;
      final completer = Completer<int>();

      final future1 = coordinator.coordinate(
        'pullToRefresh',
        () {
          callCount++;
          return completer.future;
        },
      );
      final future2 = coordinator.coordinate(
        'pullToRefresh',
        () {
          callCount++;
          return completer.future;
        },
      );

      completer.complete(100);

      final result1 = await future1;
      final result2 = await future2;

      expect(result1, 100);
      expect(result2, 100);
      expect(callCount, 1, reason: 'action should only execute once');
    });

    test('allows concurrent different-reason requests', () async {
      var callCount = 0;
      final completer1 = Completer<String>();
      final completer2 = Completer<String>();

      final future1 = coordinator.coordinate(
        'pullToRefresh',
        () {
          callCount++;
          return completer1.future;
        },
      );
      final future2 = coordinator.coordinate(
        'reconnect',
        () {
          callCount++;
          return completer2.future;
        },
      );

      completer1.complete('refresh-done');
      completer2.complete('reconnect-done');

      expect(await future1, 'refresh-done');
      expect(await future2, 'reconnect-done');
      expect(callCount, 2);
    });

    test('clears reason after completion, allows next request', () async {
      var callCount = 0;

      await coordinator.coordinate(
        'initialLoad',
        () async {
          callCount++;
          return 'first';
        },
      );

      final result = await coordinator.coordinate(
        'initialLoad',
        () async {
          callCount++;
          return 'second';
        },
      );

      expect(result, 'second');
      expect(callCount, 2,
          reason: 'second call should execute after first completes');
    });

    test('clears reason after failure, allows retry', () async {
      var callCount = 0;

      try {
        await coordinator.coordinate<String>(
          'pullToRefresh',
          () async {
            callCount++;
            throw Exception('network error');
          },
        );
      } catch (_) {
        // expected
      }

      final result = await coordinator.coordinate(
        'pullToRefresh',
        () async {
          callCount++;
          return 'retry-success';
        },
      );

      expect(result, 'retry-success');
      expect(callCount, 2);
    });

    test('propagates error to all deduplicated callers', () async {
      final completer = Completer<int>();

      final future1 = coordinator.coordinate(
        'reconnect',
        () => completer.future,
      );
      final future2 = coordinator.coordinate(
        'reconnect',
        () => completer.future,
      );

      completer.completeError(Exception('server down'));

      expect(future1, throwsException);
      expect(future2, throwsException);
    });

    test('isInFlight returns true while request is pending', () async {
      final completer = Completer<void>();

      expect(coordinator.isInFlight('initialLoad'), isFalse);

      final future = coordinator.coordinate(
        'initialLoad',
        () => completer.future,
      );

      expect(coordinator.isInFlight('initialLoad'), isTrue);

      completer.complete();
      await future;

      expect(coordinator.isInFlight('initialLoad'), isFalse);
    });

    test('cancelAll cancels pending requests', () async {
      final completer = Completer<int>();

      // ignore: unused_local_variable — we need to start the request
      final future = coordinator.coordinate(
        'initialLoad',
        () => completer.future,
      );

      coordinator.cancelAll();

      // After cancelAll, reason should be cleared
      expect(coordinator.isInFlight('initialLoad'), isFalse);

      // The original future should still complete normally when
      // the underlying completer resolves (cancelAll just clears tracking)
      completer.complete(42);
      // No error thrown — the coordinator just stops tracking
    });

    test('dispose prevents new requests', () async {
      coordinator.dispose();

      // After dispose, coordinate should throw
      expect(
        () => coordinator.coordinate('initialLoad', () async => 42),
        throwsStateError,
      );
    });
  });
}
