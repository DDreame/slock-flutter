import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';

void main() {
  group('VoiceRecorderService', () {
    test('initial state is idle', () {
      final service = VoiceRecorderService();
      expect(service.state, VoiceRecorderState.idle);
      expect(service.filePath, isNull);
      expect(service.elapsed, Duration.zero);
    });

    test('exposes an amplitude stream', () {
      final service = VoiceRecorderService();
      expect(service.amplitudeStream, isA<Stream<double>>());
    });

    test('exposes a state stream', () {
      final service = VoiceRecorderService();
      expect(service.stateStream, isA<Stream<VoiceRecorderState>>());
    });

    test('exposes an elapsed stream', () {
      final service = VoiceRecorderService();
      expect(service.elapsedStream, isA<Stream<Duration>>());
    });

    test('dispose does not throw', () {
      final service = VoiceRecorderService();
      expect(() => service.dispose(), returnsNormally);
    });

    test('cancel from idle state is a no-op', () async {
      final service = VoiceRecorderService();
      await service.cancel();
      expect(service.state, VoiceRecorderState.idle);
    });

    test('stop from idle state is a no-op and returns null', () async {
      final service = VoiceRecorderService();
      final path = await service.stop();
      expect(path, isNull);
      expect(service.state, VoiceRecorderState.idle);
    });
  });

  group('VoiceRecorderState enum', () {
    test('has idle, recording, and paused values', () {
      expect(
          VoiceRecorderState.values,
          containsAll([
            VoiceRecorderState.idle,
            VoiceRecorderState.recording,
          ]));
    });
  });
}
