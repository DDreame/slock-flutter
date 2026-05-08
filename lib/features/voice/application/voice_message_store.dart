import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';

/// State for the voice message recording/playback UI.
class VoiceMessageState {
  const VoiceMessageState({
    this.recordingState = VoiceRecorderState.idle,
    this.elapsed = Duration.zero,
    this.amplitudes = const [],
    this.recordedFilePath,
  });

  /// Current recording state.
  final VoiceRecorderState recordingState;

  /// Elapsed recording time.
  final Duration elapsed;

  /// Normalized amplitude samples (0.0–1.0) for waveform visualization.
  final List<double> amplitudes;

  /// Path to the recorded file after stopping.
  final String? recordedFilePath;

  VoiceMessageState copyWith({
    VoiceRecorderState? recordingState,
    Duration? elapsed,
    List<double>? amplitudes,
    String? recordedFilePath,
    bool clearRecordedFilePath = false,
  }) {
    return VoiceMessageState(
      recordingState: recordingState ?? this.recordingState,
      elapsed: elapsed ?? this.elapsed,
      amplitudes: amplitudes ?? this.amplitudes,
      recordedFilePath: clearRecordedFilePath
          ? null
          : (recordedFilePath ?? this.recordedFilePath),
    );
  }
}

/// Riverpod notifier for voice message recording state.
///
/// This store manages the recording lifecycle and exposes state changes
/// to the UI. The actual recording is handled by [VoiceRecorderService].
final voiceMessageStoreProvider =
    NotifierProvider<VoiceMessageStore, VoiceMessageState>(
  VoiceMessageStore.new,
);

class VoiceMessageStore extends Notifier<VoiceMessageState> {
  @override
  VoiceMessageState build() => const VoiceMessageState();

  /// Update the recording state.
  void setRecordingState(VoiceRecorderState recordingState) {
    state = state.copyWith(recordingState: recordingState);
  }

  /// Add a raw amplitude value (dBFS) and normalize it to 0.0–1.0.
  ///
  /// dBFS range: -160 (silence) to 0 (maximum).
  /// Normalization: clamp to [-160, 0], then map to [0.0, 1.0].
  void addAmplitude(double dBFS) {
    final clamped = dBFS.clamp(-160.0, 0.0);
    // Non-linear mapping for better visual representation:
    // Use a power curve so quiet sounds are more visible.
    final normalized = math.pow(1 + clamped / 160.0, 2.0).toDouble();
    state = state.copyWith(amplitudes: [...state.amplitudes, normalized]);
  }

  /// Update the elapsed recording time.
  void setElapsed(Duration elapsed) {
    state = state.copyWith(elapsed: elapsed);
  }

  /// Store the path to the recorded file.
  void setRecordedFilePath(String path) {
    state = state.copyWith(recordedFilePath: path);
  }

  /// Reset to the initial idle state.
  void reset() {
    state = const VoiceMessageState();
  }
}
