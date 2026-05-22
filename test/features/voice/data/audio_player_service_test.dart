import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
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

    test('play cancels previous player state subscription before relistening',
        () async {
      final player = _FakeVoiceAudioPlayer();
      final service = AudioPlayerService(player: player);

      await service.play('/tmp/audio.m4a');
      await service.play('/tmp/audio.m4a');

      expect(player.playerStateListenCount, 2);
      expect(player.playerStateCancelCount, 1);

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

class _FakeVoiceAudioPlayer implements VoiceAudioPlayer {
  final StreamController<PlayerState> _playerStateController =
      StreamController<PlayerState>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();

  int playerStateListenCount = 0;
  int playerStateCancelCount = 0;
  final Duration _duration = const Duration(seconds: 3);

  @override
  Stream<PlayerState> get playerStateStream => Stream<PlayerState>.multi(
        (controller) {
          playerStateListenCount++;
          final subscription = _playerStateController.stream.listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );
          controller.onCancel = () async {
            playerStateCancelCount++;
            await subscription.cancel();
          };
        },
      );

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Duration? get duration => _duration;

  @override
  Future<void> dispose() async {
    await _playerStateController.close();
    await _positionController.close();
    await _durationController.close();
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<Duration?> setFilePath(String path) async => _duration;

  @override
  Future<Duration?> setUrl(String url) async => _duration;

  @override
  Future<void> stop() async {}
}
