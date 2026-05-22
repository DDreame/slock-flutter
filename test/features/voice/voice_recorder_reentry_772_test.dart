// =============================================================================
// #772 — P1 Voice Recorder Concurrent-Start Race (Re-entrancy Guard)
//
// Verifies:
// A. Two concurrent startRecording() calls on the PRODUCTION
//    VoiceRecordingController result in only ONE native recorder start.
// B. Guard resets after completion — subsequent start works.
// C. Guard resets on error — not permanently stuck.
// D. Service-level race still exists (proves controller guard is needed).
// E. Widget-level lifecycle: controller stays alive when widget watches it.
//
// Load-bearing proof:
//   Reverting the `if (_isStartingRecording) return` guard in
//   VoiceRecordingController.startRecording() causes test A to fail
//   (two native starts instead of one).
//   Reverting `ref.watch(voiceRecordingControllerProvider)` from the
//   production widget causes test E to fail (controller disposes early).
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/application/voice_recording_controller.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';
import 'package:slock_app/features/voice/presentation/widgets/voice_recording_lifecycle_binding.dart';

void main() {
  group('#772 — VoiceRecordingController re-entrancy guard', () {
    late ProviderContainer container;
    late VoiceRecordingController controller;
    late _SlowPermissionRecorder fakeRecorder;

    setUp(() {
      fakeRecorder = _SlowPermissionRecorder();
      final fakeService = VoiceRecorderService(
        recorder: fakeRecorder,
        tempDirPathOverride: '/tmp/test772',
      );

      container = ProviderContainer();
      // Keep the provider alive.
      container.listen(voiceRecordingControllerProvider, (_, __) {});
      container.listen(voiceMessageStoreProvider, (_, __) {});

      controller = container.read(voiceRecordingControllerProvider.notifier);
      controller.setRecorder(fakeService);
    });

    tearDown(() {
      container.dispose();
    });

    // -----------------------------------------------------------------------
    // A: Two concurrent startRecording() calls → only ONE native start.
    // THIS IS THE LOAD-BEARING TEST. Removing the guard makes it fail.
    // -----------------------------------------------------------------------
    test(
      'concurrent startRecording() calls: only first reaches native start',
      () async {
        // First call: blocks on hasPermission() (completer not yet resolved).
        final call1 = controller.startRecording();

        // Second call: fires while first is still awaiting permission.
        final call2 = controller.startRecording();

        // Second should return immediately with alreadyStarting.
        // Resolve permission so first can complete.
        fakeRecorder.permissionCompleter.complete(true);

        final result1 = await call1;
        final result2 = await call2;

        expect(result1, StartRecordingResult.success);
        expect(result2, StartRecordingResult.alreadyStarting,
            reason: '#772: second concurrent call must be rejected by guard');
        expect(fakeRecorder.startCallCount, 1,
            reason: '#772: only one native recorder.start() must execute');
      },
    );

    // -----------------------------------------------------------------------
    // B: Guard resets after completion — subsequent start works.
    // -----------------------------------------------------------------------
    test(
      'guard resets after completion — sequential starts both succeed',
      () async {
        // First call: grant permission immediately.
        fakeRecorder.permissionCompleter.complete(true);
        final result1 = await controller.startRecording();
        expect(result1, StartRecordingResult.success);
        expect(fakeRecorder.startCallCount, 1);

        // Stop recording so service allows a new start.
        await controller.stopRecording();

        // Reset recorder for second call (new completer).
        fakeRecorder.resetForNextCall();

        // Second call: should succeed since guard has reset.
        fakeRecorder.permissionCompleter.complete(true);
        final result2 = await controller.startRecording();
        expect(result2, StartRecordingResult.success,
            reason: 'Guard must reset in finally block for sequential calls');
        expect(fakeRecorder.startCallCount, 2);
      },
    );

    // -----------------------------------------------------------------------
    // C: Guard resets on error — not permanently stuck.
    // -----------------------------------------------------------------------
    test(
      'guard resets on permission error — next start succeeds',
      () async {
        // First call: permission throws.
        fakeRecorder.permissionCompleter
            .completeError(Exception('Permission check failed'));
        final result1 = await controller.startRecording();
        expect(result1, StartRecordingResult.error);

        // Guard must have reset despite the error.
        fakeRecorder.resetForNextCall();
        fakeRecorder.permissionCompleter.complete(true);
        final result2 = await controller.startRecording();
        expect(result2, StartRecordingResult.success,
            reason:
                'Guard must reset even on exception (finally block in controller)');
      },
    );

    // -----------------------------------------------------------------------
    // D: Service-level race (proves controller guard is needed).
    // -----------------------------------------------------------------------
    test(
      'SERVICE-LEVEL RACE: concurrent service.start() calls both execute '
      '(proves controller guard is needed)',
      () async {
        final directRecorder = _SlowPermissionRecorder();
        final directService = VoiceRecorderService(
          recorder: directRecorder,
          tempDirPathOverride: '/tmp/test772_direct',
        );

        // Two concurrent calls directly on the service (bypassing controller).
        final first = directService.start();
        final second = directService.start();

        directRecorder.permissionCompleter.complete(true);
        await first;
        await second;

        // Both calls reach native start because service guard is sync-only.
        expect(directRecorder.startCallCount, 2,
            reason:
                '#772: service-level guard is insufficient — proves controller '
                'guard is essential');

        directService.dispose();
      },
    );
  });

  // =========================================================================
  // E: Widget lifecycle — controller stays alive when widget watches it.
  // This test fails if ref.watch(voiceRecordingControllerProvider) is removed
  // from the PRODUCTION VoiceRecordingLifecycleBinding widget because the
  // AutoDispose provider disposes after the event loop when nothing watches it.
  //
  // Load-bearing proof: removing ref.watch() from
  // lib/.../voice_recording_lifecycle_binding.dart causes this test to fail.
  // =========================================================================
  group('#772 — VoiceRecordingController widget lifecycle', () {
    testWidgets(
      'controller survives event loop when production VoiceRecordingLifecycleBinding watches it',
      (tester) async {
        final fakeRecorder = _SlowPermissionRecorder();
        final fakeService = VoiceRecorderService(
          recorder: fakeRecorder,
          tempDirPathOverride: '/tmp/test772_lifecycle',
        );

        // Pump the PRODUCTION VoiceRecordingLifecycleBinding widget —
        // the same widget ConversationDetailPage uses in lib/.
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: VoiceRecordingLifecycleBinding(
                child: SizedBox.shrink(),
              ),
            ),
          ),
        );

        // Get the controller through the widget's container.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(VoiceRecordingLifecycleBinding)),
        );

        // Inject the fake recorder.
        final controller =
            container.read(voiceRecordingControllerProvider.notifier);
        controller.setRecorder(fakeService);

        // Grant permission immediately so startRecording completes.
        fakeRecorder.permissionCompleter.complete(true);

        // Start recording through the controller.
        final result = await controller.startRecording();
        expect(result, StartRecordingResult.success);
        expect(fakeRecorder.startCallCount, 1);

        // Pump several frames — if the provider auto-disposed, the controller
        // would be gone and a new instance would be created on next read.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // The same controller instance must still be alive.
        final controllerAfterPump =
            container.read(voiceRecordingControllerProvider.notifier);
        expect(identical(controller, controllerAfterPump), isTrue,
            reason: '#772: controller must survive event loop — '
                'production VoiceRecordingLifecycleBinding ref.watch keeps '
                'AutoDispose alive');

        // Recorder must not have been disposed.
        expect(fakeRecorder.disposeCallCount, 0,
            reason:
                '#772: recorder must not be disposed while widget is alive');
      },
    );
  });
}

/// AudioRecorder fake where hasPermission() blocks on a Completer,
/// simulating a slow platform channel call.
class _SlowPermissionRecorder implements AudioRecorder {
  Completer<bool> permissionCompleter = Completer<bool>();
  int startCallCount = 0;
  int disposeCallCount = 0;

  /// Reset for a second sequential call (fresh completer).
  void resetForNextCall() {
    permissionCompleter = Completer<bool>();
  }

  @override
  Future<bool> hasPermission() => permissionCompleter.future;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startCallCount++;
  }

  @override
  Future<String?> stop() async => '/tmp/test772/recording.m4a';

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> isRecording() async => startCallCount > 0;

  @override
  Future<bool> isPaused() async => false;

  @override
  Future<Amplitude> getAmplitude() async =>
      Amplitude(current: -40.0, max: -10.0);

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }

  @override
  Stream<RecordState> onStateChanged() => const Stream.empty();

  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
