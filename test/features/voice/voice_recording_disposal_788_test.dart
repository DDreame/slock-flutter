// =============================================================================
// #788 — VoiceRecordingController Disposal Guard
//
// Verifies: Disposing the controller during stopRecording() or
// cancelRecording() (after recorder.stop()/cancel() completes) does NOT throw
// StateError from ref.read() — the _disposed guard bails before reset().
//
// Load-bearing proof:
//   Reverting `if (_disposed) return` in stopRecording()/cancelRecording()
//   causes these tests to fail with StateError from ref.read on disposed
//   container.
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/application/voice_recording_controller.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';

void main() {
  group('#788 — VoiceRecordingController disposal guard', () {
    test('stopRecording: dispose during recorder.stop() does not throw',
        () async {
      final stopCompleter = Completer<String?>();
      final fakeService = _DelayedVoiceRecorderService(
        stopCompleter: stopCompleter,
      );

      final container = ProviderContainer();
      final sub =
          container.listen(voiceRecordingControllerProvider, (_, __) {});
      container.listen(voiceMessageStoreProvider, (_, __) {});

      final controller =
          container.read(voiceRecordingControllerProvider.notifier);
      controller.setRecorder(fakeService);

      // Start stopRecording — will await the completer.
      final stopFuture = controller.stopRecording();

      // Dispose BEFORE the completer resolves — simulates navigation away.
      sub.close();
      container.dispose();

      // Complete the stop — without the _disposed guard this would
      // trigger ref.read() on a disposed container → StateError.
      stopCompleter.complete('/tmp/recording.m4a');

      // Must complete without StateError.
      final path = await stopFuture;
      expect(path, '/tmp/recording.m4a');
    });

    test('cancelRecording: dispose during recorder.cancel() does not throw',
        () async {
      final cancelCompleter = Completer<void>();
      final fakeService = _DelayedVoiceRecorderService(
        cancelCompleter: cancelCompleter,
      );

      final container = ProviderContainer();
      final sub =
          container.listen(voiceRecordingControllerProvider, (_, __) {});
      container.listen(voiceMessageStoreProvider, (_, __) {});

      final controller =
          container.read(voiceRecordingControllerProvider.notifier);
      controller.setRecorder(fakeService);

      // Start cancelRecording — will await the completer.
      final cancelFuture = controller.cancelRecording();

      // Dispose BEFORE the completer resolves.
      sub.close();
      container.dispose();

      // Complete the cancel — without the _disposed guard this would throw.
      cancelCompleter.complete();

      // Must complete without StateError.
      await cancelFuture;
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// VoiceRecorderService whose stop()/cancel() await a Completer, letting us
/// dispose the controller mid-operation.
class _DelayedVoiceRecorderService implements VoiceRecorderService {
  _DelayedVoiceRecorderService({
    this.stopCompleter,
    this.cancelCompleter,
  });

  final Completer<String?>? stopCompleter;
  final Completer<void>? cancelCompleter;

  @override
  Future<String?> stop() async {
    if (stopCompleter != null) return stopCompleter!.future;
    return null;
  }

  @override
  Future<void> cancel() async {
    if (cancelCompleter != null) await cancelCompleter!.future;
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
