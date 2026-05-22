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

    test('rapid play keeps stale listener from resetting current playback',
        () async {
      final player = _FakeVoiceAudioPlayer();
      final service = AudioPlayerService(player: player);

      await service.play('/tmp/first.m4a');
      player.delayNextPlayerStateCancel();

      await service.play('/tmp/second.m4a');

      expect(player.playerStateListenCount, 2);
      expect(player.playerStateCancelCount, 1);
      expect(service.currentPath, '/tmp/second.m4a');
      expect(service.state, AudioPlaybackState.playing);

      player.emitPlayerStateToSubscription(
        0,
        PlayerState(false, ProcessingState.completed),
      );

      expect(service.currentPath, '/tmp/second.m4a');
      expect(service.state, AudioPlaybackState.playing);

      player.completeDelayedPlayerStateCancel();
      await service.dispose();
    });

    test('older pending play cannot overwrite a newer play', () async {
      final player = _FakeVoiceAudioPlayer();
      final service = AudioPlayerService(player: player);
      player.delaySetFilePath('/tmp/first.m4a');

      final firstPlay = service.play('/tmp/first.m4a');
      await Future<void>.delayed(Duration.zero);

      await service.play('/tmp/second.m4a');
      expect(service.currentPath, '/tmp/second.m4a');
      expect(service.state, AudioPlaybackState.playing);

      player.completeSetFilePath('/tmp/first.m4a');
      await firstPlay;

      expect(service.currentPath, '/tmp/second.m4a');
      expect(service.state, AudioPlaybackState.playing);

      await service.dispose();
    });

    test('dispose ignores player state subscription cancel failures', () async {
      final player = _FakeVoiceAudioPlayer();
      final service = AudioPlayerService(player: player);

      await service.play('/tmp/audio.m4a');
      player.throwOnPlayerStateCancel = true;

      await service.dispose();

      expect(player.disposed, isTrue);
    });
  });

  group('AudioAttachmentPlayerPool', () {
    test('load while another attachment is active returns duration', () async {
      final player = _FakeAudioPlayerController();
      final pool = AudioAttachmentPlayerPool(player);

      await pool.play('first', '/tmp/first.m4a');
      final duration = await pool.load('second', '/tmp/second.m4a');

      expect(duration, const Duration(seconds: 12));
      expect(player.stopCount, 1);
      expect(player.loadCount, 1);
      expect(player.loadedPaths, ['/tmp/second.m4a']);
      expect(pool.isActive('second'), isTrue);

      pool.dispose();
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

class _FakeAudioPlayerController implements AudioPlayerController {
  final _stateController = StreamController<AudioPlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  int loadCount = 0;
  int playCount = 0;
  int stopCount = 0;
  int disposeCount = 0;
  final loadedPaths = <String>[];

  @override
  AudioPlaybackState state = AudioPlaybackState.stopped;

  @override
  String? currentPath;

  @override
  Stream<AudioPlaybackState> get stateStream => _stateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Future<Duration?> load(String path) async {
    loadCount++;
    loadedPaths.add(path);
    currentPath = path;
    const duration = Duration(seconds: 12);
    _durationController.add(duration);
    return duration;
  }

  @override
  Future<void> play(String path) async {
    playCount++;
    currentPath = path;
    state = AudioPlaybackState.playing;
    _stateController.add(state);
  }

  @override
  Future<void> pause() async {
    state = AudioPlaybackState.paused;
    _stateController.add(state);
  }

  @override
  Future<void> resume() async {
    state = AudioPlaybackState.playing;
    _stateController.add(state);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    state = AudioPlaybackState.stopped;
    _stateController.add(state);
  }

  @override
  Future<void> seek(Duration position) async {
    _positionController.add(position);
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
  }
}

class _FakeVoiceAudioPlayer implements VoiceAudioPlayer {
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final Map<String, Completer<Duration?>> _setFilePathCompleters = {};
  final List<_FakePlayerStateSubscription> _playerStateSubscriptions = [];

  int playerStateListenCount = 0;
  int playerStateCancelCount = 0;
  bool throwOnPlayerStateCancel = false;
  bool disposed = false;
  Completer<void>? _playerStateCancelCompleter;
  final Duration _duration = const Duration(seconds: 3);

  @override
  Stream<PlayerState> get playerStateStream => _FakePlayerStateStream(this);

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Duration? get duration => _duration;

  void delaySetFilePath(String path) {
    _setFilePathCompleters[path] = Completer<Duration?>();
  }

  void completeSetFilePath(String path) {
    _setFilePathCompleters[path]?.complete(_duration);
  }

  void delayNextPlayerStateCancel() {
    _playerStateCancelCompleter = Completer<void>();
  }

  void completeDelayedPlayerStateCancel() {
    _playerStateCancelCompleter?.complete();
    _playerStateCancelCompleter = null;
  }

  void emitPlayerStateToSubscription(int index, PlayerState state) {
    _playerStateSubscriptions[index].emit(state);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
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
  Future<Duration?> setFilePath(String path) async {
    final completer = _setFilePathCompleters[path];
    if (completer != null) return completer.future;
    return _duration;
  }

  @override
  Future<Duration?> setUrl(String url) async => _duration;

  @override
  Future<void> stop() async {}
}

class _FakePlayerStateStream extends Stream<PlayerState> {
  const _FakePlayerStateStream(this.player);

  final _FakeVoiceAudioPlayer player;

  @override
  StreamSubscription<PlayerState> listen(
    void Function(PlayerState event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    player.playerStateListenCount++;
    final subscription = _FakePlayerStateSubscription(
      player: player,
      onData: onData,
    );
    player._playerStateSubscriptions.add(subscription);
    return subscription;
  }
}

class _FakePlayerStateSubscription implements StreamSubscription<PlayerState> {
  _FakePlayerStateSubscription({
    required this.player,
    required void Function(PlayerState event)? onData,
  }) : _onData = onData;

  final _FakeVoiceAudioPlayer player;
  void Function(PlayerState event)? _onData;
  bool _isCanceled = false;
  bool _isPaused = false;

  void emit(PlayerState state) {
    if (_isCanceled || _isPaused) return;
    _onData?.call(state);
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) async => futureValue as E;

  @override
  Future<void> cancel() async {
    player.playerStateCancelCount++;
    if (player.throwOnPlayerStateCancel) {
      throw StateError('cancel failed');
    }
    final completer = player._playerStateCancelCompleter;
    if (completer != null) {
      await completer.future;
    }
    _isCanceled = true;
  }

  @override
  bool get isPaused => _isPaused;

  @override
  void onData(void Function(PlayerState data)? handleData) {
    _onData = handleData;
  }

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void onError(Function? handleError) {}

  @override
  void pause([Future<void>? resumeSignal]) {
    _isPaused = true;
    resumeSignal?.whenComplete(resume);
  }

  @override
  void resume() {
    _isPaused = false;
  }
}
