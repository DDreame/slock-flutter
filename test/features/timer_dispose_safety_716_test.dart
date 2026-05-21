// =============================================================================
// #716 — Timer/Dispose Safety + Push Timeout
//
// A. P1: Push token deregister hang blocks new token registration indefinitely
// B. P2: ConversationDetailSendMixin Timer fires during dispose window
// C. P2: ListTypingIndicatorNotifier Timer fires on stale notifier
// =============================================================================

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/push_token/application/push_token_lifecycle_binding.dart';
import 'package:slock_app/features/push_token/data/push_token_repository.dart';
import 'package:slock_app/features/realtime/application/list_typing_indicator_store.dart';

void main() {
  group('#716A — P1: Push token deregister timeout', () {
    test('deregister hanging beyond 10s does not block new token registration',
        () {
      fakeAsync((async) {
        final repo = _HangingDeregisterRepository();
        var completed = false;

        // Call the exposed test function directly — deregister will hang
        // but should timeout after 10s and proceed to register.
        deregisterThenRegisterForTest(
          repo,
          'old-token',
          'new-token',
          platform: 'android',
          crashReporter: _FakeCrashReporter(),
        ).then((_) => completed = true);

        // Before timeout, register should not have been called.
        expect(repo.registerCallCount, 0);

        // Advance past the 10-second timeout.
        async.elapse(const Duration(seconds: 11));

        // After timeout, register should have been called.
        expect(completed, isTrue,
            reason: 'Future should complete after timeout');
        expect(repo.registerCallCount, 1,
            reason: 'Register must proceed after deregister timeout');
        expect(repo.lastRegisteredToken, 'new-token');
      });
    });
  });

  group('#716B — P2: _disposed guard prevents StateError on Timer fire', () {
    // The ConversationDetailSendMixin's _sendMixinDisposed guard uses the
    // same pattern as ListTypingIndicatorNotifier's _disposed guard: a bool
    // flag checked at the top of a Timer callback to prevent ref.read/state
    // mutation after disposal. We prove the pattern works with a minimal
    // Notifier that replicates the exact behavior:
    //   1. Starts a Timer that mutates state on fire.
    //   2. onDispose sets _disposed = true (but does NOT cancel the timer,
    //      simulating the race window the guard protects against).
    //   3. Timer fires after disposal → guard prevents StateError.

    test(
        'Timer callback guarded by _disposed flag is no-op after disposal '
        '(pattern proof for send mixin + typing indicator)', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        final sub = container.listen(_disposedGuardPatternProvider, (_, __) {});

        final notifier = container.read(_disposedGuardPatternProvider.notifier);

        // Start a 2-second timer that will attempt to set state.
        notifier.startTimer();

        // Verify timer hasn't fired yet.
        expect(container.read(_disposedGuardPatternProvider), 0);

        // Close subscription → disposal scheduled on next microtask.
        sub.close();
        // Flush microtasks → onDispose runs, sets _disposed = true.
        // NOTE: Timer is intentionally NOT cancelled in onDispose to
        // simulate the race window.
        async.flushMicrotasks();

        // Advance time past the 2-second timer. Without the _disposed
        // guard, this would throw StateError (setting state on disposed
        // notifier). With the guard, it's a no-op.
        async.elapse(const Duration(seconds: 3));

        // If we get here, the _disposed guard prevented the crash.
        // Also verify state was NOT mutated (guard returned early).
        expect(notifier.timerFiredAfterDispose, isTrue,
            reason: 'Timer DID fire (proving test exercises the path)');
        expect(notifier.stateMutationAttempted, isFalse,
            reason: 'Guard prevented state mutation');

        container.dispose();
      });
    });
  });

  group('#716C — P2: ListTypingIndicatorNotifier dispose guards', () {
    test('addTyper after full disposal is no-op — no StateError', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        final sub = container.listen(
            listTypingIndicatorStoreProvider('ch-1'), (_, __) {});

        final notifier =
            container.read(listTypingIndicatorStoreProvider('ch-1').notifier);

        // Add a typer to prove the provider works before disposal.
        notifier.addTyper(userId: 'user-1', displayName: 'Alice');
        expect(
            container.read(listTypingIndicatorStoreProvider('ch-1')).isActive,
            isTrue);

        // Close subscription → disposal on next microtask.
        sub.close();
        // Flush microtasks → onDispose runs: _disposed = true, timers
        // cancelled, maps cleared.
        async.flushMicrotasks();

        // Calling addTyper on the disposed notifier. Without the
        // `if (_disposed) return;` guard, this would reach
        // `state = ListTypingIndicatorState(...)` which throws
        // StateError on a disposed AutoDisposeNotifier.
        notifier.addTyper(userId: 'user-2', displayName: 'Bob');

        // Advance time to prove any timer created by addTyper (which
        // shouldn't happen due to early return) doesn't fire.
        async.elapse(const Duration(seconds: 6));

        container.dispose();
        // No exception = _disposed guard in addTyper() works.
      });
    });

    test('removeTyper after disposal is safe — no StateError', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        final sub = container.listen(
            listTypingIndicatorStoreProvider('ch-2'), (_, __) {});

        final notifier =
            container.read(listTypingIndicatorStoreProvider('ch-2').notifier);
        notifier.addTyper(userId: 'user-1', displayName: 'Alice');

        sub.close();
        async.flushMicrotasks();

        // removeTyper on disposed notifier — would throw if state is set.
        notifier.removeTyper('user-1');

        container.dispose();
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Pattern test notifier — reproduces the exact _disposed guard pattern used
// in ConversationDetailSendMixin and ListTypingIndicatorNotifier.
// ---------------------------------------------------------------------------

final _disposedGuardPatternProvider =
    NotifierProvider.autoDispose<_DisposedGuardPatternNotifier, int>(
  _DisposedGuardPatternNotifier.new,
);

class _DisposedGuardPatternNotifier extends AutoDisposeNotifier<int> {
  bool _disposed = false;
  bool timerFiredAfterDispose = false;
  bool stateMutationAttempted = false;

  @override
  int build() {
    ref.onDispose(() {
      _disposed = true;
      // NOTE: Intentionally NOT cancelling the timer here to simulate the
      // race condition the _disposed guard protects against. In production,
      // timers ARE cancelled in onDispose, but the guard is defense-in-depth
      // for edge cases (e.g., timer fires in the same event loop iteration).
    });
    return 0;
  }

  void startTimer() {
    Timer(const Duration(seconds: 2), () {
      if (_disposed) {
        // Guard fired — record that the timer DID execute but was blocked.
        timerFiredAfterDispose = true;
        return;
      }
      stateMutationAttempted = true;
      state = state + 1;
    });
  }
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _HangingDeregisterRepository implements PushTokenRepository {
  int registerCallCount = 0;
  String? lastRegisteredToken;
  final _deregisterCompleter = Completer<void>();

  @override
  Future<void> registerToken({
    required String token,
    String? platform,
  }) async {
    registerCallCount++;
    lastRegisteredToken = token;
  }

  @override
  Future<void> deregisterToken({
    required String token,
    String? authToken,
  }) {
    // Never completes — simulates a hanging request.
    return _deregisterCompleter.future;
  }
}

class _FakeCrashReporter implements CrashReporter {
  @override
  Future<void> init() async {}

  @override
  void captureException(Object error,
      {StackTrace? stackTrace, Map<String, dynamic>? extra}) {}

  @override
  void captureFlutterError(FlutterErrorDetails details) {}

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {}

  @override
  void setUser(String? userId, {String? displayName}) {}
}
