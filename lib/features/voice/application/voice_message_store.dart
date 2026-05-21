import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';

/// State for the voice message recording/playback UI.
@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceMessageState &&
          runtimeType == other.runtimeType &&
          recordingState == other.recordingState &&
          elapsed == other.elapsed &&
          listEquals(amplitudes, other.amplitudes) &&
          recordedFilePath == other.recordedFilePath;

  @override
  int get hashCode => Object.hash(
        recordingState,
        elapsed,
        Object.hashAll(amplitudes),
        recordedFilePath,
      );
}

/// Riverpod notifier for voice message recording state.
///
/// This store manages the recording lifecycle and exposes state changes
/// to the UI. The actual recording is handled by [VoiceRecorderService].
///
/// AutoDispose: scoped to the conversation page lifecycle. When the page
/// is disposed and all watchers are removed, the store auto-resets to idle.
/// This prevents stale recording state from leaking across conversations.
final voiceMessageStoreProvider =
    AutoDisposeNotifierProvider<VoiceMessageStore, VoiceMessageState>(
  VoiceMessageStore.new,
);

class VoiceMessageStore extends AutoDisposeNotifier<VoiceMessageState> {
  @override
  bool updateShouldNotify(VoiceMessageState previous, VoiceMessageState next) =>
      previous != next;
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

/// Notifier for the voice waveform amplitude cache.
///
/// Provides a structured insertion API ([put]) so eviction logic
/// (Phase B) can be added at the insertion point without callers
/// needing to change.
class VoiceWaveformCacheNotifier
    extends StateNotifier<Map<String, List<double>>> {
  VoiceWaveformCacheNotifier([Map<String, List<double>>? initialData])
      : super(initialData ?? {});

  /// Maximum number of cached waveform entries.
  static const maxSize = 50;

  /// Insert or update a waveform entry.
  ///
  /// When the cache exceeds [maxSize], the oldest (first-inserted)
  /// entries are evicted to keep memory bounded.
  void put(String name, List<double> samples) {
    final updated = {...state, name: samples};
    if (updated.length > maxSize) {
      final excess = updated.length - maxSize;
      final keysToRemove = updated.keys.take(excess).toList();
      for (final key in keysToRemove) {
        updated.remove(key);
      }
    }
    state = updated;
  }
}

/// Cache of recorded waveform amplitudes, keyed by attachment name.
///
/// Populated when the user sends a voice recording so the inline player
/// can display the real waveform captured during recording.
final voiceWaveformCacheProvider = StateNotifierProvider<
    VoiceWaveformCacheNotifier, Map<String, List<double>>>(
  (ref) => VoiceWaveformCacheNotifier(),
);
