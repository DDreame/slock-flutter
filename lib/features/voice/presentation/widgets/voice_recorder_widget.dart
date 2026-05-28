import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';
import 'package:slock_app/features/voice/presentation/widgets/audio_waveform_painter.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Inline recording UI that replaces the composer when recording.
///
/// Shows a cancel button, recording indicator + waveform, elapsed time,
/// and a send button.
class VoiceRecorderWidget extends ConsumerWidget {
  const VoiceRecorderWidget({
    super.key,
    required this.onSend,
    required this.onCancel,
  });

  /// Hoisted border radius to avoid per-build allocations.
  static final borderRadius = BorderRadius.circular(24);

  /// Called when the user taps the send/stop button to finalize the recording.
  final VoidCallback onSend;

  /// Called when the user taps cancel to discard the recording.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceMessageStoreProvider);
    final theme = Theme.of(context);
    final isRecording = state.recordingState == VoiceRecorderState.recording;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Row(
        children: [
          // Cancel button.
          IconButton(
            key: const ValueKey('voice-cancel'),
            icon: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.error,
            ),
            onPressed: onCancel,
            tooltip: context.l10n.voiceRecorderCancel,
          ),

          // Recording indicator + elapsed time.
          if (isRecording)
            Container(
              key: const ValueKey('recording-indicator'),
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),

          Text(
            _formatDuration(state.elapsed),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),

          const SizedBox(width: 8),

          // Waveform visualization.
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: context.l10n.voiceWaveformSemantics,
              child: SizedBox(
                key: const ValueKey('voice-waveform'),
                height: 32,
                child: CustomPaint(
                  painter: AudioWaveformPainter(
                    amplitudes:
                        ref.read(voiceMessageStoreProvider.notifier).amplitudes,
                    amplitudeCount: state.amplitudeCount,
                    color: theme.colorScheme.primary,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button.
          IconButton(
            key: const ValueKey('voice-send'),
            icon: Icon(
              Icons.send,
              color: theme.colorScheme.primary,
            ),
            onPressed: onSend,
            tooltip: context.l10n.voiceRecorderSend,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
