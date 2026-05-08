import 'package:flutter/material.dart';

/// CustomPainter that renders an audio waveform as vertical bars.
///
/// Used for both live recording visualization and playback scrubbing.
/// [amplitudes] are normalized values (0.0–1.0) representing bar heights.
/// [progress] (0.0–1.0) controls the active/inactive split for playback.
class AudioWaveformPainter extends CustomPainter {
  const AudioWaveformPainter({
    required this.amplitudes,
    required this.color,
    this.inactiveColor,
    this.progress,
    this.barWidth = 3.0,
    this.barSpacing = 2.0,
    this.minBarHeight = 2.0,
  });

  /// Normalized amplitude values (0.0–1.0).
  final List<double> amplitudes;

  /// Color for active (played) bars.
  final Color color;

  /// Color for inactive (unplayed) bars. Defaults to [color] at 30% opacity.
  final Color? inactiveColor;

  /// Playback progress (0.0–1.0). Null means no progress indicator (recording
  /// mode — all bars use [color]).
  final double? progress;

  /// Width of each bar in logical pixels.
  final double barWidth;

  /// Spacing between bars in logical pixels.
  final double barSpacing;

  /// Minimum bar height to ensure visibility for silent sections.
  final double minBarHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final effectiveInactive = inactiveColor ?? color.withAlpha(77);

    final totalBarWidth = barWidth + barSpacing;
    final maxBars = (size.width / totalBarWidth).floor();
    final barsToRender = amplitudes.length > maxBars
        ? amplitudes.sublist(amplitudes.length - maxBars)
        : amplitudes;

    final activePaint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;
    final inactivePaint = Paint()
      ..color = effectiveInactive
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final maxBarHeight = size.height - minBarHeight;

    for (var i = 0; i < barsToRender.length; i++) {
      final amplitude = barsToRender[i].clamp(0.0, 1.0);
      final barHeight =
          (amplitude * maxBarHeight).clamp(minBarHeight, maxBarHeight);

      final x = i * totalBarWidth + barWidth / 2;
      if (x > size.width) break;

      // Determine if this bar is in the "played" portion.
      final isActive =
          progress == null || i < (barsToRender.length * progress!).ceil();

      final paint = isActive ? activePaint : inactivePaint;
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint..strokeWidth = barWidth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AudioWaveformPainter oldDelegate) {
    return !identical(amplitudes, oldDelegate.amplitudes) ||
        progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        inactiveColor != oldDelegate.inactiveColor;
  }
}
