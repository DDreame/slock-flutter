import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Playback state machine.
enum AudioPlaybackState {
  /// No audio loaded or playback completed.
  stopped,

  /// Audio is actively playing.
  playing,

  /// Audio is paused (can be resumed).
  paused,
}

/// Wraps `just_audio` for playing voice message audio files.
///
/// Exposes streams for position, duration, and playback state.
/// The underlying [AudioPlayer] is created lazily on first access
/// to avoid binding initialization issues in non-widget contexts.
class AudioPlayerService {
  AudioPlayerService();

  AudioPlayer? _player;
  String? _currentPath;
  AudioPlaybackState _state = AudioPlaybackState.stopped;
  StreamSubscription<PlayerState>? _playerStateSub;

  AudioPlayer get _lazyPlayer => _player ??= AudioPlayer();

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  /// Current playback state.
  AudioPlaybackState get state => _state;

  /// Path of the currently loaded audio file.
  String? get currentPath => _currentPath;

  /// Stream of playback state changes.
  Stream<AudioPlaybackState> get stateStream =>
      _lazyPlayer.playerStateStream.map(_mapPlayerState);

  /// Stream of current playback position.
  Stream<Duration> get positionStream => _lazyPlayer.positionStream;

  /// Stream of total audio duration.
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
  Future<Duration?> load(String path) async {
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
  }

  /// Load and play an audio file at [path].
  ///
  /// Accepts both local file paths and HTTP/HTTPS URLs.
  /// If a different file is already playing, it is stopped first.
  Future<void> play(String path) async {
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
      _state = _mapPlayerState(playerState);
      if (playerState.processingState == ProcessingState.completed) {
        _state = AudioPlaybackState.stopped;
        player.seek(Duration.zero);
        player.pause();
      }
    });

    await player.play();
    _state = AudioPlaybackState.playing;
  }

  /// Pause playback. No-op if not playing.
  Future<void> pause() async {
    if (_state != AudioPlaybackState.playing) return;
    await _lazyPlayer.pause();
    _state = AudioPlaybackState.paused;
  }

  /// Resume playback from the current position.
  Future<void> resume() async {
    if (_state != AudioPlaybackState.paused) return;
    await _lazyPlayer.play();
    _state = AudioPlaybackState.playing;
  }

  /// Stop playback and reset position.
  Future<void> stop() async {
    if (_state == AudioPlaybackState.stopped) return;
    await _lazyPlayer.stop();
    _state = AudioPlaybackState.stopped;
  }

  /// Seek to a specific position.
  Future<void> seek(Duration position) async {
    await _lazyPlayer.seek(position);
  }

  /// Release resources.
  Future<void> dispose() async {
    _playerStateSub?.cancel();
    await _player?.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

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
