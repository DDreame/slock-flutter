import 'package:flutter/material.dart';
import 'package:slock_app/features/voice/presentation/widgets/audio_waveform_painter.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Inline audio player widget for voice messages in chat bubbles.
///
/// Displays a play/pause button, waveform scrubber, and duration/position.
class VoiceMessageBubble extends StatelessWidget {
  const VoiceMessageBubble({
    super.key,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.waveform,
    required this.onPlayPause,
    required this.onSeek,
  });

  /// Total duration of the audio.
  final Duration duration;

  /// Current playback position.
  final Duration position;

  /// Whether the audio is currently playing.
  final bool isPlaying;

  /// Normalized waveform data (0.0–1.0) for visualization.
  final List<double> waveform;

  /// Called when the play/pause button is tapped.
  final VoidCallback onPlayPause;

  /// Called when the user taps the waveform to seek. Value is 0.0–1.0.
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/pause button.
        IconButton(
          key: const ValueKey('voice-play-pause'),
          icon: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: theme.colorScheme.primary,
          ),
          onPressed: onPlayPause,
          visualDensity: VisualDensity.compact,
          tooltip: isPlaying ? 'Pause' : 'Play',
        ),

        // Waveform + duration.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Waveform scrubber with accessibility semantics.
              Semantics(
                label: context.l10n.voiceMessageScrubber,
                value: '${(progress * 100).round()}%',
                slider: true,
                onIncrease: () => onSeek((progress + 0.1).clamp(0.0, 1.0)),
                onDecrease: () => onSeek((progress - 0.1).clamp(0.0, 1.0)),
                child: LayoutBuilder(
                  builder: (_, constraints) => GestureDetector(
                    onTapDown: (details) {
                      final fraction =
                          (details.localPosition.dx / constraints.maxWidth)
                              .clamp(0.0, 1.0);
                      onSeek(fraction);
                    },
                    child: SizedBox(
                      height: 28,
                      child: CustomPaint(
                        painter: AudioWaveformPainter(
                          amplitudes: waveform,
                          color: theme.colorScheme.primary,
                          inactiveColor: theme.colorScheme.outlineVariant,
                          progress: progress,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 2),

              // Duration / position label.
              Text(
                _formatDuration(isPlaying ? position : duration),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
