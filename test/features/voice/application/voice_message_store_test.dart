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
      expect(state.amplitudeCount, 0);
      expect(state.elapsed, Duration.zero);
      expect(state.recordedFilePath, isNull);
    });

    test('state copyWith preserves values', () {
      const state = VoiceMessageState(
        recordingState: VoiceRecorderState.recording,
        elapsed: Duration(seconds: 5),
        amplitudeCount: 2,
        recordedFilePath: '/tmp/test.m4a',
      );

      final copy = state.copyWith(
        elapsed: const Duration(seconds: 10),
      );

      expect(copy.recordingState, VoiceRecorderState.recording);
      expect(copy.elapsed, const Duration(seconds: 10));
      expect(copy.amplitudeCount, 2);
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
      expect(state.amplitudeCount, 0);
      expect(notifier.amplitudes, isEmpty);
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

      final amps = notifier.amplitudes;
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

      final amps = notifier.amplitudes;
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

  group('voiceWaveformCacheProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial cache is empty', () {
      final cache = container.read(voiceWaveformCacheProvider);
      expect(cache, isEmpty);
    });

    test('caching amplitudes stores them keyed by name', () {
      container.read(voiceWaveformCacheProvider.notifier).put(
        'voice_123.m4a',
        [0.3, 0.7, 0.5],
      );

      final cache = container.read(voiceWaveformCacheProvider);
      expect(cache['voice_123.m4a'], [0.3, 0.7, 0.5]);
    });

    test('multiple entries are preserved', () {
      container
          .read(voiceWaveformCacheProvider.notifier)
          .put('voice_1.m4a', [0.1, 0.2]);
      container
          .read(voiceWaveformCacheProvider.notifier)
          .put('voice_2.m4a', [0.8, 0.9]);

      final cache = container.read(voiceWaveformCacheProvider);
      expect(cache, hasLength(2));
      expect(cache['voice_1.m4a'], [0.1, 0.2]);
      expect(cache['voice_2.m4a'], [0.8, 0.9]);
    });

    test('evicts the least recently accessed waveform', () {
      final notifier = container.read(voiceWaveformCacheProvider.notifier);
      for (var i = 0; i < VoiceWaveformCacheNotifier.maxSize; i++) {
        notifier.put('voice_$i.m4a', [i.toDouble()]);
      }

      expect(notifier.get('voice_0.m4a'), [0.0],
          reason: 'Reading an entry must mark it as recently used');
      notifier.put('voice_50.m4a', [50.0]);

      final cache = container.read(voiceWaveformCacheProvider);
      expect(cache, hasLength(VoiceWaveformCacheNotifier.maxSize));
      expect(cache.containsKey('voice_0.m4a'), isTrue,
          reason: 'Recently accessed waveform should survive eviction');
      expect(cache.containsKey('voice_1.m4a'), isFalse,
          reason: 'The oldest unaccessed waveform should be evicted first');
      expect(cache.containsKey('voice_50.m4a'), isTrue);
    });

    test('updated waveform survives eviction as recently used', () {
      final notifier = container.read(voiceWaveformCacheProvider.notifier);
      for (var i = 0; i < VoiceWaveformCacheNotifier.maxSize; i++) {
        notifier.put('voice_$i.m4a', [i.toDouble()]);
      }

      notifier.put('voice_0.m4a', [100.0]);
      notifier.put('voice_50.m4a', [50.0]);

      final cache = container.read(voiceWaveformCacheProvider);
      expect(cache.containsKey('voice_0.m4a'), isTrue,
          reason: 'Updating an existing waveform should refresh recency');
      expect(cache['voice_0.m4a'], [100.0]);
      expect(cache.containsKey('voice_1.m4a'), isFalse);
      expect(cache.containsKey('voice_50.m4a'), isTrue);
    });
  });
}
