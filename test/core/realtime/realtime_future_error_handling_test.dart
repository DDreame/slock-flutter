// ---------------------------------------------------------------------------
// #552: Realtime Path Unhandled Future Errors
//
// Problem: Several hot realtime paths fire unawaited Futures without
// .catchError() or try/catch:
//   1. home_realtime_unread_binding.dart line 135: channel branch
//      persistConversationActivity() — bare unawaited, no catch
//   2. home_realtime_unread_binding.dart line 154: DM branch
//      persistConversationActivity() — bare unawaited, no catch
//   3. home_realtime_unread_binding.dart line 256: message:updated
//      persistConversationPreviewUpdate() — bare unawaited, no catch
//   4. conversation_detail_store.dart line 1300: _handleMessageCreated
//      persistMessage() + _recoverGap() inside unawaited async closure
//      with no try/catch — persistence failure skips gap recovery
//
// Contrast: the DM materialization path (line 210) correctly wraps in
// try/catch and calls crashReporter.captureException(). That is the
// pattern Phase B will replicate across all paths.
//
// Phase A: skip:true invariants locking the error-capture contracts.
//          Test-local seams simulate the persistence + gap recovery
//          patterns. Phase B will add .catchError() / try-catch to the
//          production unawaited calls and wire crashReporter capture.
//
// Invariants verified:
// INV-FUTURE-CATCH-1: persistConversationActivity throw during channel
//   message → error captured by CrashReporter, processing continues
// INV-FUTURE-CATCH-2: persistConversationActivity throw during DM
//   message → error captured by CrashReporter, processing continues
// INV-FUTURE-CATCH-3: persistConversationPreviewUpdate throw → error
//   captured by CrashReporter, processing continues
// INV-FUTURE-RECOVER-1: persistMessage throw in conversation detail →
//   error captured AND _recoverGap still executes for gap-detected msgs
// INV-FUTURE-RECOVER-2: persistMessage succeeds but _recoverGap throws
//   → error captured by CrashReporter
// ---------------------------------------------------------------------------
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/telemetry/crash_reporter.dart';

import '../../core/telemetry/crash_reporter_test.dart' show FakeCrashReporter;

// ---------------------------------------------------------------------------
// Test-local seams: mirror the production integration points that Phase B
// will fix.
//
// Phase B:
//   1. Wrap persistConversationActivity() calls in _handleMessageNew
//      with try/catch → crashReporter.captureException()
//   2. Wrap persistConversationPreviewUpdate() in _handleMessageUpdated
//      with try/catch → crashReporter.captureException()
//   3. Wrap the unawaited async closure in _handleMessageCreated with
//      try/catch so persistMessage() failure captures + still runs
//      _recoverGap(); and _recoverGap() failure also captures.
// ---------------------------------------------------------------------------

/// Test-local seam simulating the channel/DM message:new persistence
/// path in homeRealtimeUnreadBinding.
///
/// Phase B: this try/catch wrapper moves into _handleMessageNew around
/// the bare unawaited(persistConversationActivity(...)) calls.
class _TestableRealtimeActivityPersister {
  _TestableRealtimeActivityPersister({
    required this.reporter,
    required this.persistConversationActivity,
  });

  final CrashReporter reporter;
  final Future<void> Function() persistConversationActivity;

  /// Whether post-persistence processing (e.g. notifier.updateChannel*)
  /// completed. Remains true even when persistence fails — Phase B
  /// guarantees errors are swallowed so processing continues.
  bool processingCompleted = false;

  /// Simulates the channel or DM branch of _handleMessageNew.
  Future<void> handleMessageNew() async {
    try {
      await persistConversationActivity();
    } catch (e, st) {
      reporter.captureException(e, stackTrace: st);
    }
    // Post-persistence processing (notifier updates, unread increment)
    // must always execute regardless of persistence failure.
    processingCompleted = true;
  }
}

/// Test-local seam simulating the message:updated preview persistence
/// path in homeRealtimeUnreadBinding.
///
/// Phase B: this try/catch wrapper moves into _handleMessageUpdated
/// around the bare unawaited(persistConversationPreviewUpdate(...)).
class _TestableRealtimePreviewPersister {
  _TestableRealtimePreviewPersister({
    required this.reporter,
    required this.persistConversationPreviewUpdate,
  });

  final CrashReporter reporter;
  final Future<void> Function() persistConversationPreviewUpdate;

  bool processingCompleted = false;

  /// Simulates _handleMessageUpdated.
  Future<void> handleMessageUpdated() async {
    try {
      await persistConversationPreviewUpdate();
    } catch (e, st) {
      reporter.captureException(e, stackTrace: st);
    }
    processingCompleted = true;
  }
}

/// Test-local seam simulating the message persistence + gap recovery
/// path in ConversationDetailStore._handleMessageCreated.
///
/// Phase B: the unawaited async closure in _handleMessageCreated gets
/// a try/catch that:
///   - Captures persistMessage() failure AND still runs _recoverGap()
///   - Captures _recoverGap() failure independently
class _TestableMessagePersistenceHandler {
  _TestableMessagePersistenceHandler({
    required this.reporter,
    required this.persistMessage,
    required this.recoverGap,
  });

  final CrashReporter reporter;
  final Future<void> Function() persistMessage;
  final Future<void> Function() recoverGap;

  bool persistCompleted = false;
  bool gapRecoveryAttempted = false;

  /// Simulates _handleMessageCreated with gapDetected=true.
  ///
  /// Phase B contract: persistMessage failure is captured, and
  /// _recoverGap still executes. _recoverGap failure is also captured.
  Future<void> handleMessageCreated({bool gapDetected = false}) async {
    try {
      await persistMessage();
      persistCompleted = true;
    } catch (e, st) {
      reporter.captureException(e, stackTrace: st);
    }

    if (gapDetected) {
      gapRecoveryAttempted = true;
      try {
        await recoverGap();
      } catch (e, st) {
        reporter.captureException(e, stackTrace: st);
      }
    }
  }
}

void main() {
  // -----------------------------------------------------------------------
  // INV-FUTURE-CATCH-1: persistConversationActivity throw on channel msg
  // -----------------------------------------------------------------------
  group('INV-FUTURE-CATCH-1: channel persistConversationActivity error', () {
    test(
      'error captured by CrashReporter when persistence throws',
      () async {
        final reporter = FakeCrashReporter();
        final error = StateError('disk full');
        final persister = _TestableRealtimeActivityPersister(
          reporter: reporter,
          persistConversationActivity: () => Future.error(error),
        );

        await persister.handleMessageNew();

        expect(reporter.capturedErrors, hasLength(1));
        expect(reporter.capturedErrors.first, error);
      },
    );

    test(
      'processing continues after persistence failure',
      () async {
        final reporter = FakeCrashReporter();
        final persister = _TestableRealtimeActivityPersister(
          reporter: reporter,
          persistConversationActivity: () =>
              Future.error(Exception('write failed')),
        );

        await persister.handleMessageNew();

        expect(persister.processingCompleted, isTrue,
            reason: 'notifier updates must execute even when persist fails');
      },
    );

    test(
      'no error captured when persistence succeeds',
      () async {
        final reporter = FakeCrashReporter();
        final persister = _TestableRealtimeActivityPersister(
          reporter: reporter,
          persistConversationActivity: () async {},
        );

        await persister.handleMessageNew();

        expect(reporter.capturedErrors, isEmpty);
        expect(persister.processingCompleted, isTrue);
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-FUTURE-CATCH-2: persistConversationActivity throw on DM msg
  // -----------------------------------------------------------------------
  group('INV-FUTURE-CATCH-2: DM persistConversationActivity error', () {
    test(
      'error captured by CrashReporter when DM persistence throws',
      () async {
        final reporter = FakeCrashReporter();
        const error = FormatException('corrupt DM payload');
        final persister = _TestableRealtimeActivityPersister(
          reporter: reporter,
          persistConversationActivity: () => Future.error(error),
        );

        await persister.handleMessageNew();

        expect(reporter.capturedErrors, hasLength(1));
        expect(reporter.capturedErrors.first, isA<FormatException>());
      },
    );

    test(
      'DM processing continues after persistence failure',
      () async {
        final reporter = FakeCrashReporter();
        final persister = _TestableRealtimeActivityPersister(
          reporter: reporter,
          persistConversationActivity: () =>
              Future.error(StateError('DB locked')),
        );

        await persister.handleMessageNew();

        expect(persister.processingCompleted, isTrue);
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-FUTURE-CATCH-3: persistConversationPreviewUpdate throw
  // -----------------------------------------------------------------------
  group('INV-FUTURE-CATCH-3: persistConversationPreviewUpdate error', () {
    test(
      'error captured when preview update persistence throws',
      () async {
        final reporter = FakeCrashReporter();
        final error = StateError('preview write failed');
        final persister = _TestableRealtimePreviewPersister(
          reporter: reporter,
          persistConversationPreviewUpdate: () => Future.error(error),
        );

        await persister.handleMessageUpdated();

        expect(reporter.capturedErrors, hasLength(1));
        expect(reporter.capturedErrors.first, error);
      },
    );

    test(
      'notifier preview updates continue after persistence failure',
      () async {
        final reporter = FakeCrashReporter();
        final persister = _TestableRealtimePreviewPersister(
          reporter: reporter,
          persistConversationPreviewUpdate: () =>
              Future.error(Exception('IO error')),
        );

        await persister.handleMessageUpdated();

        expect(persister.processingCompleted, isTrue,
            reason:
                'channel/DM preview notifier calls must run after persist fail');
      },
    );

    test(
      'no error captured when preview update succeeds',
      () async {
        final reporter = FakeCrashReporter();
        final persister = _TestableRealtimePreviewPersister(
          reporter: reporter,
          persistConversationPreviewUpdate: () async {},
        );

        await persister.handleMessageUpdated();

        expect(reporter.capturedErrors, isEmpty);
        expect(persister.processingCompleted, isTrue);
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-FUTURE-RECOVER-1: persistMessage throw + gap recovery must run
  // -----------------------------------------------------------------------
  group('INV-FUTURE-RECOVER-1: persistMessage failure + gap recovery', () {
    test(
      'persistMessage error captured and _recoverGap still executes',
      () async {
        final reporter = FakeCrashReporter();
        var gapRecoveryCalled = false;
        final handler = _TestableMessagePersistenceHandler(
          reporter: reporter,
          persistMessage: () => Future.error(StateError('persist failed')),
          recoverGap: () async {
            gapRecoveryCalled = true;
          },
        );

        await handler.handleMessageCreated(gapDetected: true);

        expect(reporter.capturedErrors, hasLength(1),
            reason: 'persistMessage failure must be captured');
        expect(handler.persistCompleted, isFalse,
            reason: 'persistMessage did not complete successfully');
        expect(handler.gapRecoveryAttempted, isTrue,
            reason: '_recoverGap must be attempted even after persist fails');
        expect(gapRecoveryCalled, isTrue,
            reason: '_recoverGap must actually execute');
      },
    );

    test(
      'persistMessage error captured without gap when gapDetected=false',
      () async {
        final reporter = FakeCrashReporter();
        final handler = _TestableMessagePersistenceHandler(
          reporter: reporter,
          persistMessage: () => Future.error(Exception('write error')),
          recoverGap: () async {
            fail('_recoverGap should not run when gapDetected=false');
          },
        );

        await handler.handleMessageCreated(gapDetected: false);

        expect(reporter.capturedErrors, hasLength(1));
        expect(handler.gapRecoveryAttempted, isFalse);
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-FUTURE-RECOVER-2: persistMessage OK but _recoverGap throws
  // -----------------------------------------------------------------------
  group('INV-FUTURE-RECOVER-2: _recoverGap failure captured', () {
    test(
      '_recoverGap error captured when gap recovery throws',
      () async {
        final reporter = FakeCrashReporter();
        final handler = _TestableMessagePersistenceHandler(
          reporter: reporter,
          persistMessage: () async {},
          recoverGap: () => Future.error(TypeError()),
        );

        await handler.handleMessageCreated(gapDetected: true);

        expect(handler.persistCompleted, isTrue,
            reason: 'persistMessage should have succeeded');
        expect(handler.gapRecoveryAttempted, isTrue);
        expect(reporter.capturedErrors, hasLength(1),
            reason: '_recoverGap failure must be captured');
        expect(reporter.capturedErrors.first, isA<TypeError>());
      },
    );

    test(
      'both errors captured when persistMessage and _recoverGap both throw',
      () async {
        final reporter = FakeCrashReporter();
        final handler = _TestableMessagePersistenceHandler(
          reporter: reporter,
          persistMessage: () => Future.error(StateError('persist broke')),
          recoverGap: () => Future.error(const FormatException('gap broke')),
        );

        await handler.handleMessageCreated(gapDetected: true);

        expect(reporter.capturedErrors, hasLength(2),
            reason: 'Both persist and gap recovery errors must be captured');
        expect(reporter.capturedErrors[0], isA<StateError>());
        expect(reporter.capturedErrors[1], isA<FormatException>());
      },
    );

    test(
      'no error captured when both persistMessage and _recoverGap succeed',
      () async {
        final reporter = FakeCrashReporter();
        final handler = _TestableMessagePersistenceHandler(
          reporter: reporter,
          persistMessage: () async {},
          recoverGap: () async {},
        );

        await handler.handleMessageCreated(gapDetected: true);

        expect(reporter.capturedErrors, isEmpty);
        expect(handler.persistCompleted, isTrue);
        expect(handler.gapRecoveryAttempted, isTrue);
      },
    );
  });
}
