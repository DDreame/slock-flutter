import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/voice/data/audio_player_service.dart';

void main() {
  group('AudioPlayerService', () {
    test('initial state is stopped', () {
      final service = AudioPlayerService();
      expect(service.state, AudioPlaybackState.stopped);
      expect(service.currentPath, isNull);
    });

    test('pause from stopped state is a no-op', () async {
      final service = AudioPlayerService();
      await service.pause();
      expect(service.state, AudioPlaybackState.stopped);
    });

    test('stop from stopped state is a no-op', () async {
      final service = AudioPlayerService();
      await service.stop();
      expect(service.state, AudioPlaybackState.stopped);
    });

    test('resume from stopped state is a no-op', () async {
      final service = AudioPlayerService();
      await service.resume();
      expect(service.state, AudioPlaybackState.stopped);
    });

    test('dispose does not throw when player was never used', () async {
      final service = AudioPlayerService();
      await service.dispose();
    });
  });

  group('AudioPlaybackState enum', () {
    test('has stopped, playing, and paused values', () {
      expect(
          AudioPlaybackState.values,
          containsAll([
            AudioPlaybackState.stopped,
            AudioPlaybackState.playing,
            AudioPlaybackState.paused,
          ]));
    });
  });
}
