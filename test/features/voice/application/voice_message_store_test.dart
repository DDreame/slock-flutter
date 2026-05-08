import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';

void main() {
  group('VoiceMessageStore', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is idle with no recording', () {
      final state = container.read(voiceMessageStoreProvider);
      expect(state.recordingState, VoiceRecorderState.idle);
      expect(state.amplitudes, isEmpty);
      expect(state.elapsed, Duration.zero);
      expect(state.recordedFilePath, isNull);
    });

    test('state copyWith preserves values', () {
      const state = VoiceMessageState(
        recordingState: VoiceRecorderState.recording,
        elapsed: Duration(seconds: 5),
        amplitudes: [0.5, 0.8],
        recordedFilePath: '/tmp/test.m4a',
      );

      final copy = state.copyWith(
        elapsed: const Duration(seconds: 10),
      );

      expect(copy.recordingState, VoiceRecorderState.recording);
      expect(copy.elapsed, const Duration(seconds: 10));
      expect(copy.amplitudes, [0.5, 0.8]);
      expect(copy.recordedFilePath, '/tmp/test.m4a');
    });

    test('state copyWith can clear recordedFilePath', () {
      const state = VoiceMessageState(
        recordedFilePath: '/tmp/test.m4a',
      );

      final copy = state.copyWith(clearRecordedFilePath: true);
      expect(copy.recordedFilePath, isNull);
    });

    test('reset returns to initial state', () {
      final notifier = container.read(voiceMessageStoreProvider.notifier);
      notifier.setRecordingState(VoiceRecorderState.recording);
      notifier.addAmplitude(0.5);
      notifier.setElapsed(const Duration(seconds: 3));

      notifier.reset();

      final state = container.read(voiceMessageStoreProvider);
      expect(state.recordingState, VoiceRecorderState.idle);
      expect(state.amplitudes, isEmpty);
      expect(state.elapsed, Duration.zero);
      expect(state.recordedFilePath, isNull);
    });

    test('setRecordingState updates state', () {
      final notifier = container.read(voiceMessageStoreProvider.notifier);
      notifier.setRecordingState(VoiceRecorderState.recording);
      expect(
        container.read(voiceMessageStoreProvider).recordingState,
        VoiceRecorderState.recording,
      );
    });

    test('addAmplitude appends normalized values to list', () {
      final notifier = container.read(voiceMessageStoreProvider.notifier);
      // These are dBFS values. addAmplitude normalizes them to 0..1.
      notifier.addAmplitude(-80);
      notifier.addAmplitude(-40);
      notifier.addAmplitude(-10);

      final amps = container.read(voiceMessageStoreProvider).amplitudes;
      expect(amps, hasLength(3));
      // All should be between 0.0 and 1.0.
      for (final a in amps) {
        expect(a, greaterThanOrEqualTo(0.0));
        expect(a, lessThanOrEqualTo(1.0));
      }
      // Higher dBFS (closer to 0) should produce higher normalized values.
      expect(amps[2], greaterThan(amps[1]));
      expect(amps[1], greaterThan(amps[0]));
    });

    test('addAmplitude normalizes values from dBFS to 0..1', () {
      final notifier = container.read(voiceMessageStoreProvider.notifier);
      // -160 dBFS (silence) → 0.0
      notifier.addAmplitude(-160);
      // 0 dBFS (max) → 1.0
      notifier.addAmplitude(0);
      // -40 dBFS (moderate) → ~0.75
      notifier.addAmplitude(-40);

      final amps = container.read(voiceMessageStoreProvider).amplitudes;
      expect(amps[0], closeTo(0.0, 0.01));
      expect(amps[1], closeTo(1.0, 0.01));
      expect(amps[2], greaterThan(0.5));
      expect(amps[2], lessThan(1.0));
    });

    test('setElapsed updates elapsed', () {
      final notifier = container.read(voiceMessageStoreProvider.notifier);
      notifier.setElapsed(const Duration(seconds: 42));
      expect(
        container.read(voiceMessageStoreProvider).elapsed,
        const Duration(seconds: 42),
      );
    });

    test('setRecordedFilePath stores the path', () {
      final notifier = container.read(voiceMessageStoreProvider.notifier);
      notifier.setRecordedFilePath('/tmp/voice_123.m4a');
      expect(
        container.read(voiceMessageStoreProvider).recordedFilePath,
        '/tmp/voice_123.m4a',
      );
    });
  });
}
