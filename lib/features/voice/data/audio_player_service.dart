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

final activeAudioPlayerProvider = StateProvider<AudioPlayerController?>((ref) {
  return null;
});

/// Wraps `just_audio` for playing voice message audio files.
///
/// Exposes streams for position, duration, and playback state.
/// The underlying [AudioPlayer] is created lazily on first access
/// to avoid binding initialization issues in non-widget contexts.
class AudioPlayerService implements AudioPlayerController {
  AudioPlayerService();

  AudioPlayer? _player;
  String? _currentPath;
  AudioPlaybackState _state = AudioPlaybackState.stopped;
  StreamSubscription<PlayerState>? _playerStateSub;
  final _stateController = StreamController<AudioPlaybackState>.broadcast();

  AudioPlayer get _lazyPlayer => _player ??= AudioPlayer();

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
    try {
      final player = _lazyPlayer;
      if (_currentPath != path) {
        if (path.startsWith('http://') || path.startsWith('https://')) {
          await player.setUrl(path);
        } else {
          await player.setFilePath(path);
        }
        _currentPath = path;
      }

      // Listen for completion to reset state.
      _playerStateSub?.cancel();
      _playerStateSub = player.playerStateStream.listen((playerState) {
        final nextState = _mapPlayerState(playerState);
        _setState(nextState);
        if (playerState.processingState == ProcessingState.completed) {
          _setState(AudioPlaybackState.stopped);
          unawaited(_resetCompletedPlayback(player));
        }
      }, onError: (_) {
        _setState(AudioPlaybackState.error);
      });

      await player.play();
      _setState(AudioPlaybackState.playing);
    } catch (_) {
      _setState(AudioPlaybackState.error);
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
      await _playerStateSub?.cancel();
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

  Future<void> _resetCompletedPlayback(AudioPlayer player) async {
    try {
      await player.seek(Duration.zero);
      await player.pause();
    } catch (_) {
      _setState(AudioPlaybackState.error);
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
