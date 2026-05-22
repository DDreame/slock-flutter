import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Recording state machine.
enum VoiceRecorderState {
  /// No recording in progress.
  idle,

  /// Actively capturing audio.
  recording,
}

/// Wraps the `record` package for microphone capture with AAC/M4A output.
///
/// Exposes streams for amplitude (waveform), elapsed time, and state changes.
/// Call [start] to begin, [stop] to finalize, or [cancel] to discard.
class VoiceRecorderService {
  VoiceRecorderService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  final _stateController = StreamController<VoiceRecorderState>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();
  final _elapsedController = StreamController<Duration>.broadcast();

  Timer? _amplitudeTimer;
  Timer? _elapsedTimer;
  DateTime? _recordingStartedAt;
  String? _currentPath;

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  /// Current recorder state.
  VoiceRecorderState _state = VoiceRecorderState.idle;
  VoiceRecorderState get state => _state;

  /// Path to the current or most recent recording file.
  String? get filePath => _currentPath;

  /// Check (and request) microphone permission.
  ///
  /// Returns `true` when the permission is granted.
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Elapsed recording time.
  Duration get elapsed {
    if (_recordingStartedAt == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartedAt!);
  }

  /// Stream of state transitions.
  Stream<VoiceRecorderState> get stateStream => _stateController.stream;

  /// Stream of amplitude values (dBFS, typically -160 to 0).
  /// Emitted at ~100ms intervals during recording.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Stream of elapsed recording duration (~100ms updates).
  Stream<Duration> get elapsedStream => _elapsedController.stream;

  // ---------------------------------------------------------------------------
  // Recording controls
  // ---------------------------------------------------------------------------

  /// Generates a unique absolute path in the system temp directory for a
  /// voice recording. Uses timestamp + microseconds to ensure uniqueness
  /// even under rapid successive calls (#729).
  ///
  /// [tempDirPath] can be supplied in tests to bypass the platform channel.
  @visibleForTesting
  static Future<String> generateRecordingPath({String? tempDirPath}) async {
    final dirPath = tempDirPath ?? (await getTemporaryDirectory()).path;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '$dirPath/voice_$timestamp.m4a';
  }

  /// Start recording to a temp file in AAC/M4A format.
  ///
  /// Requires microphone permission (should be requested before calling).
  /// [outputPath] is the full path to the output file. If null, a temp path is
  /// generated using [generateRecordingPath].
  Future<void> start({String? outputPath}) async {
    if (_state == VoiceRecorderState.recording) return;

    final path = outputPath ?? await generateRecordingPath();

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
      ),
      path: path,
    );

    _currentPath = path;
    _recordingStartedAt = DateTime.now();
    _state = VoiceRecorderState.recording;
    _stateController.add(_state);

    // Poll amplitude and elapsed time.
    _amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) async {
        try {
          final amplitude = await _recorder.getAmplitude();
          if (!_amplitudeController.isClosed) {
            _amplitudeController.add(amplitude.current);
          }
        } catch (_) {
          // Recorder may have been stopped between timer ticks.
        }
      },
    );
    _elapsedTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        if (!_elapsedController.isClosed && _recordingStartedAt != null) {
          _elapsedController
              .add(DateTime.now().difference(_recordingStartedAt!));
        }
      },
    );
  }

  /// Stop recording and return the path to the finalized M4A file.
  ///
  /// Returns null if not currently recording.
  Future<String?> stop() async {
    if (_state != VoiceRecorderState.recording) return null;

    _stopTimers();
    final path = await _recorder.stop();
    _state = VoiceRecorderState.idle;
    _stateController.add(_state);
    _recordingStartedAt = null;
    return path ?? _currentPath;
  }

  /// Cancel the current recording and discard the file.
  Future<void> cancel() async {
    if (_state != VoiceRecorderState.recording) return;

    _stopTimers();
    await _recorder.stop();
    _state = VoiceRecorderState.idle;
    _stateController.add(_state);

    // Delete the temp audio file to prevent orphaned M4A accumulation (#713).
    final path = _currentPath;
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Best-effort deletion; don't crash on I/O failure.
      }
    }

    _currentPath = null;
    _recordingStartedAt = null;
  }

  /// Release resources.
  void dispose() {
    _stopTimers();
    _recorder.dispose();
    _stateController.close();
    _amplitudeController.close();
    _elapsedController.close();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _stopTimers() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }
}
