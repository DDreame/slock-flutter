import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';

/// Result of attempting to start a voice recording.
enum StartRecordingResult {
  /// Recording started successfully.
  success,

  /// A start is already in progress (re-entrancy guard hit).
  alreadyStarting,

  /// Microphone permission was denied by the user.
  permissionDenied,

  /// An exception occurred during permission check or recording start.
  error,
}

/// Controller that owns the voice recording lifecycle and the re-entrancy
/// guard that prevents concurrent starts (#772).
///
/// This is the single source of truth for the "is a start in progress?" flag.
/// The conversation page delegates to this controller rather than managing
/// the guard internally, making it directly testable.
///
/// AutoDispose: scoped to conversation page lifecycle. When the page
/// navigates away and all watchers are removed, subscriptions are cleaned up.
final voiceRecordingControllerProvider = AutoDisposeNotifierProvider<
    VoiceRecordingController, VoiceRecordingControllerState>(
  VoiceRecordingController.new,
);

/// Minimal state exposed by the controller.
@immutable
class VoiceRecordingControllerState {
  const VoiceRecordingControllerState({
    this.isStarting = false,
  });

  /// True while a startRecording() call is in flight.
  final bool isStarting;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceRecordingControllerState &&
          runtimeType == other.runtimeType &&
          isStarting == other.isStarting;

  @override
  int get hashCode => isStarting.hashCode;
}

class VoiceRecordingController
    extends AutoDisposeNotifier<VoiceRecordingControllerState> {
  VoiceRecorderService? _recorder;
  StreamSubscription<VoiceRecorderState>? _voiceStateSub;
  StreamSubscription<double>? _voiceAmplitudeSub;
  StreamSubscription<Duration>? _voiceElapsedSub;

  /// Whether a startRecording() call is currently in flight.
  /// Synchronous flag for the re-entrancy guard (#772).
  bool _isStartingRecording = false;

  @override
  VoiceRecordingControllerState build() {
    ref.onDispose(_cleanup);
    return const VoiceRecordingControllerState();
  }

  /// Visible for testing — allows injection of a fake recorder.
  @visibleForTesting
  void setRecorder(VoiceRecorderService recorder) {
    _recorder = recorder;
  }

  /// The underlying recorder service (lazily created).
  VoiceRecorderService get recorder {
    return _recorder ??= VoiceRecorderService();
  }

  /// Attempt to start recording. Returns immediately with
  /// [StartRecordingResult.alreadyStarting] if another start is in flight.
  ///
  /// This is the guarded entry point (#772). The synchronous boolean check
  /// ensures that even if two taps fire in the same microtask, only one
  /// proceeds past the guard.
  Future<StartRecordingResult> startRecording() async {
    if (_isStartingRecording) return StartRecordingResult.alreadyStarting;
    _isStartingRecording = true;
    state = const VoiceRecordingControllerState(isStarting: true);
    try {
      return await _startRecordingImpl();
    } finally {
      _isStartingRecording = false;
      state = const VoiceRecordingControllerState(isStarting: false);
    }
  }

  Future<StartRecordingResult> _startRecordingImpl() async {
    final rec = recorder;
    final store = ref.read(voiceMessageStoreProvider.notifier);

    // Check/request microphone permission.
    try {
      final granted = await rec.hasPermission();
      if (!granted) {
        return StartRecordingResult.permissionDenied;
      }
    } on Exception {
      return StartRecordingResult.error;
    }

    // Start recording.
    try {
      _voiceStateSub?.cancel();
      _voiceAmplitudeSub?.cancel();
      _voiceElapsedSub?.cancel();

      _voiceStateSub = rec.stateStream.listen((s) {
        store.setRecordingState(s);
      });
      _voiceAmplitudeSub = rec.amplitudeStream.listen((a) {
        store.addAmplitude(a);
      });
      _voiceElapsedSub = rec.elapsedStream.listen((d) {
        store.setElapsed(d);
      });

      await rec.start();
      store.setRecordingState(VoiceRecorderState.recording);
      return StartRecordingResult.success;
    } on Exception {
      // Clean up any partial subscriptions.
      _voiceStateSub?.cancel();
      _voiceAmplitudeSub?.cancel();
      _voiceElapsedSub?.cancel();
      store.reset();
      return StartRecordingResult.error;
    }
  }

  /// Stop recording and return the file path. Cleans up subscriptions.
  /// Returns null if not recording.
  Future<String?> stopRecording() async {
    _cancelSubscriptions();
    final path = await recorder.stop();
    ref.read(voiceMessageStoreProvider.notifier).reset();
    return path;
  }

  /// Cancel recording and discard the file. Cleans up subscriptions.
  Future<void> cancelRecording() async {
    _cancelSubscriptions();
    await recorder.cancel();
    ref.read(voiceMessageStoreProvider.notifier).reset();
  }

  /// Cancel stream subscriptions without stopping the recorder.
  void _cancelSubscriptions() {
    _voiceStateSub?.cancel();
    _voiceAmplitudeSub?.cancel();
    _voiceElapsedSub?.cancel();
  }

  void _cleanup() {
    _cancelSubscriptions();
    _recorder?.dispose();
  }
}
