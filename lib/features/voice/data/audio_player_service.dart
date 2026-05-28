import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Playback state machine.
enum AudioPlaybackState {
  /// No audio loaded or playback completed.
  stopped,

  /// Audio is actively playing.
  playing,

  /// Audio is paused (can be resumed).
  paused,

  /// Last playback operation failed.
  error,
}

abstract class AudioPlayerController {
  AudioPlaybackState get state;
  String? get currentPath;
  Stream<AudioPlaybackState> get stateStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;

  Future<Duration?> load(String path);
  Future<void> play(String path);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

final audioPlayerServiceFactoryProvider =
    Provider<AudioPlayerController Function()>((ref) => AudioPlayerService.new);

final audioAttachmentPlayerPoolProvider =
    StateNotifierProvider.autoDispose<AudioAttachmentPlayerPool, String?>(
        (ref) {
  return AudioAttachmentPlayerPool(
    ref.read(audioPlayerServiceFactoryProvider)(),
  );
});

class AudioAttachmentPlayerPool extends StateNotifier<String?> {
  AudioAttachmentPlayerPool(this._player) : super(null);

  final AudioPlayerController _player;

  AudioPlayerController get player => _player;

  bool isActive(String key) => state == key;

  Future<Duration?> load(String key, String path) async {
    if (state != null && state != key) {
      await _player.stop();
      state = key;
    }
    return _player.load(path);
  }

  Future<void> play(String key, String path) async {
    if (state != null && state != key) {
      await _player.stop();
    }
    state = key;
    await _player.play(path);
  }

  Future<void> pause(String key) async {
    if (state != key) return;
    await _player.pause();
  }

  Future<void> resume(String key) async {
    if (state != null && state != key) {
      await _player.stop();
    }
    state = key;
    await _player.resume();
  }

  Future<void> seek(String key, Duration position) async {
    if (state != key) return;
    await _player.seek(position);
  }

  void clearIfActive(String key) {
    if (state == key) {
      state = null;
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }
}

/// Wraps `just_audio` for playing voice message audio files.
///
/// Exposes streams for position, duration, and playback state.
/// The underlying [AudioPlayer] is created lazily on first access
/// to avoid binding initialization issues in non-widget contexts.
abstract class VoiceAudioPlayer {
  Stream<PlayerState> get playerStateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Duration? get duration;

  Future<Duration?> setUrl(String url);
  Future<Duration?> setFilePath(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class _JustAudioPlayerAdapter implements VoiceAudioPlayer {
  _JustAudioPlayerAdapter() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Duration? get duration => _player.duration;

  @override
  Future<Duration?> setUrl(String url) => _player.setUrl(url);

  @override
  Future<Duration?> setFilePath(String path) => _player.setFilePath(path);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}

class AudioPlayerService implements AudioPlayerController {
  AudioPlayerService({VoiceAudioPlayer? player}) : _player = player;

  VoiceAudioPlayer? _player;
  String? _currentPath;
  AudioPlaybackState _state = AudioPlaybackState.stopped;
  StreamSubscription<PlayerState>? _playerStateSub;
  int _playbackGeneration = 0;
  final _stateController = StreamController<AudioPlaybackState>.broadcast();

  VoiceAudioPlayer get _lazyPlayer => _player ??= _JustAudioPlayerAdapter();

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  /// Current playback state.
  @override
  AudioPlaybackState get state => _state;

  /// Path of the currently loaded audio file.
  @override
  String? get currentPath => _currentPath;

  /// Stream of playback state changes.
  @override
  Stream<AudioPlaybackState> get stateStream => _stateController.stream;

  /// Stream of current playback position.
  @override
  Stream<Duration> get positionStream => _lazyPlayer.positionStream;

  /// Stream of total audio duration.
  @override
  Stream<Duration> get durationStream =>
      _lazyPlayer.durationStream.where((d) => d != null).cast<Duration>();

  // ---------------------------------------------------------------------------
  // Playback controls
  // ---------------------------------------------------------------------------

  /// Load an audio source without starting playback.
  ///
  /// Accepts both local file paths and HTTP/HTTPS URLs.
  /// Returns the audio duration, or `null` if it cannot be determined.
  /// After loading, [durationStream] and other streams become active.
  @override
  Future<Duration?> load(String path) async {
    try {
      final player = _lazyPlayer;
      if (_currentPath != path) {
        Duration? duration;
        if (path.startsWith('http://') || path.startsWith('https://')) {
          duration = await player.setUrl(path);
        } else {
          duration = await player.setFilePath(path);
        }
        _currentPath = path;
        return duration;
      }
      return player.duration;
    } catch (_) {
      _setState(AudioPlaybackState.error);
      return null;
    }
  }

  /// Load and play an audio file at [path].
  ///
  /// Accepts both local file paths and HTTP/HTTPS URLs.
  /// If a different file is already playing, it is stopped first.
  @override
  Future<void> play(String path) async {
    final generation = ++_playbackGeneration;
    try {
      final player = _lazyPlayer;
      if (_currentPath != path) {
        if (path.startsWith('http://') || path.startsWith('https://')) {
          await player.setUrl(path);
        } else {
          await player.setFilePath(path);
        }
        if (!_isCurrentPlayback(generation)) return;
        _currentPath = path;
      }

      final previousSub = _playerStateSub;
      _playerStateSub = null;
      unawaited(_cancelPlayerStateSubscription(previousSub));

      final subscription = player.playerStateStream.listen((playerState) {
        if (!_isCurrentPlayback(generation)) return;
        final nextState = _mapPlayerState(playerState);
        _setState(nextState);
        if (playerState.processingState == ProcessingState.completed) {
          _setState(AudioPlaybackState.stopped);
          unawaited(_resetCompletedPlayback(player, generation));
        }
      }, onError: (_) {
        if (_isCurrentPlayback(generation)) {
          _setState(AudioPlaybackState.error);
        }
      });
      _playerStateSub = subscription;

      await player.play();
      if (_isCurrentPlayback(generation)) {
        _setState(AudioPlaybackState.playing);
      }
    } catch (_) {
      if (_isCurrentPlayback(generation)) {
        _setState(AudioPlaybackState.error);
      }
    }
  }

  /// Pause playback. No-op if not playing.
  @override
  Future<void> pause() async {
    if (_state != AudioPlaybackState.playing) return;
    try {
      await _lazyPlayer.pause();
      _setState(AudioPlaybackState.paused);
    } catch (_) {
      _setState(AudioPlaybackState.error);
    }
  }

  /// Resume playback from the current position.
  @override
  Future<void> resume() async {
    if (_state != AudioPlaybackState.paused) return;
    try {
      await _lazyPlayer.play();
      _setState(AudioPlaybackState.playing);
    } catch (_) {
      _setState(AudioPlaybackState.error);
    }
  }

  /// Stop playback and reset position.
  @override
  Future<void> stop() async {
    if (_state == AudioPlaybackState.stopped) return;
    try {
      await _lazyPlayer.stop();
      _setState(AudioPlaybackState.stopped);
    } catch (_) {
      _setState(AudioPlaybackState.error);
    }
  }

  /// Seek to a specific position.
  @override
  Future<void> seek(Duration position) async {
    try {
      await _lazyPlayer.seek(position);
    } catch (_) {
      _setState(AudioPlaybackState.error);
    }
  }

  /// Release resources.
  @override
  Future<void> dispose() async {
    try {
      _playbackGeneration++;
      final subscription = _playerStateSub;
      _playerStateSub = null;
      await _cancelPlayerStateSubscription(subscription);
      await _player?.dispose();
    } catch (_) {
      _setState(AudioPlaybackState.error);
    } finally {
      await _stateController.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _setState(AudioPlaybackState nextState) {
    if (_state == nextState) return;
    _state = nextState;
    if (!_stateController.isClosed) {
      _stateController.add(nextState);
    }
  }

  bool _isCurrentPlayback(int generation) => _playbackGeneration == generation;

  Future<void> _cancelPlayerStateSubscription(
    StreamSubscription<PlayerState>? subscription,
  ) async {
    try {
      await subscription?.cancel();
    } catch (_) {}
  }

  Future<void> _resetCompletedPlayback(
    VoiceAudioPlayer player,
    int generation,
  ) async {
    try {
      if (!_isCurrentPlayback(generation)) return;
      await player.seek(Duration.zero);
      if (!_isCurrentPlayback(generation)) return;
      await player.pause();
    } catch (_) {
      if (_isCurrentPlayback(generation)) {
        _setState(AudioPlaybackState.error);
      }
    }
  }

  AudioPlaybackState _mapPlayerState(PlayerState playerState) {
    if (playerState.processingState == ProcessingState.completed) {
      return AudioPlaybackState.stopped;
    }
    if (playerState.playing) return AudioPlaybackState.playing;
    return playerState.processingState == ProcessingState.idle
        ? AudioPlaybackState.stopped
        : AudioPlaybackState.paused;
  }
}
