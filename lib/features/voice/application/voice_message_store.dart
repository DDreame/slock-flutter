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
    this.amplitudeCount = 0,
    this.recordedFilePath,
  });

  /// Current recording state.
  final VoiceRecorderState recordingState;

  /// Elapsed recording time.
  final Duration elapsed;

  /// Number of amplitude samples collected. Used as a change signal for
  /// the waveform widget — actual samples live in VoiceMessageStore._amplitudes
  /// (growable list, O(1) append). (#774)
  final int amplitudeCount;

  /// Path to the recorded file after stopping.
  final String? recordedFilePath;

  VoiceMessageState copyWith({
    VoiceRecorderState? recordingState,
    Duration? elapsed,
    int? amplitudeCount,
    String? recordedFilePath,
    bool clearRecordedFilePath = false,
  }) {
    return VoiceMessageState(
      recordingState: recordingState ?? this.recordingState,
      elapsed: elapsed ?? this.elapsed,
      amplitudeCount: amplitudeCount ?? this.amplitudeCount,
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
          amplitudeCount == other.amplitudeCount &&
          recordedFilePath == other.recordedFilePath;

  @override
  int get hashCode => Object.hash(
        recordingState,
        elapsed,
        amplitudeCount,
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
  /// Growable mutable list for O(1) amplitude appends (#774).
  /// Avoids O(n) spread-copy on every 100ms tick during recording.
  final List<double> _amplitudes = [];

  /// Seeds the amplitude list with pre-existing values. Used by tests
  /// and session restore.
  @visibleForTesting
  void seedAmplitudes(List<double> values) {
    _amplitudes
      ..clear()
      ..addAll(values);
  }

  @override
  bool updateShouldNotify(VoiceMessageState previous, VoiceMessageState next) =>
      previous != next;
  @override
  VoiceMessageState build() => const VoiceMessageState();

  /// The live amplitude samples list. Exposed as unmodifiable view for the
  /// waveform painter. This is the same list instance that grows in-place.
  List<double> get amplitudes => _amplitudes;

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
    _amplitudes.add(normalized);
    state = state.copyWith(amplitudeCount: _amplitudes.length);
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
    _amplitudes.clear();
    state = const VoiceMessageState();
  }
}

/// Notifier for the voice waveform amplitude cache.
///
/// Provides a structured insertion API ([put]) so eviction logic
/// (Phase B) can be added at the insertion point without callers
/// needing to change.
class VoiceWaveformCacheNotifier
    extends AutoDisposeNotifier<Map<String, List<double>>> {
  final Map<String, int> _lastAccessByName = {};
  int _accessClock = 0;

  /// Maximum number of cached waveform entries.
  static const maxSize = 50;

  @override
  Map<String, List<double>> build() => {};

  /// Read a cached waveform entry and mark it as recently used.
  List<double>? get(String name) {
    final samples = state[name];
    if (samples == null) return null;
    _touch(name);
    return samples;
  }

  /// Insert or update a waveform entry.
  ///
  /// When the cache exceeds [maxSize], the least recently used entries
  /// are evicted to keep memory bounded.
  void put(String name, List<double> samples) {
    final updated = Map<String, List<double>>.of(state);
    updated[name] = samples;
    _touch(name);
    _evictLeastRecentlyUsed(updated);
    state = updated;
  }

  void _touch(String name) {
    _lastAccessByName[name] = _nextAccessTick();
  }

  int _nextAccessTick() => ++_accessClock;

  void _evictLeastRecentlyUsed(Map<String, List<double>> updated) {
    if (updated.length <= maxSize) return;
    final excess = updated.length - maxSize;
    final keysToRemove = updated.keys.toList()
      ..sort((a, b) {
        final accessA = _lastAccessByName[a] ?? 0;
        final accessB = _lastAccessByName[b] ?? 0;
        return accessA.compareTo(accessB);
      });
    for (final key in keysToRemove.take(excess)) {
      updated.remove(key);
      _lastAccessByName.remove(key);
    }
  }
}

/// Cache of recorded waveform amplitudes, keyed by attachment name.
///
/// Populated when the user sends a voice recording so the inline player
/// can display the real waveform captured during recording.
///
/// AutoDispose: scoped to conversation page lifecycle. Cleared when the
/// user navigates away, preventing 50-entry permanent memory leak.
/// LRU eviction (maxSize=50) still applies while the cache is alive.
final voiceWaveformCacheProvider = AutoDisposeNotifierProvider<
    VoiceWaveformCacheNotifier, Map<String, List<double>>>(
  VoiceWaveformCacheNotifier.new,
);
