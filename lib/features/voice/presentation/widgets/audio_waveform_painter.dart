import 'package:flutter/material.dart';

/// CustomPainter that renders an audio waveform as vertical bars.
///
/// Used for both live recording visualization and playback scrubbing.
/// [amplitudes] are normalized values (0.0–1.0) representing bar heights.
/// [progress] (0.0–1.0) controls the active/inactive split for playback.
/// [amplitudeCount] is the change signal — when the backing list is mutable
/// and reused across appends, identity checks cannot detect new samples.
/// The widget must pass the current count so shouldRepaint() fires (#774).
class AudioWaveformPainter extends CustomPainter {
  const AudioWaveformPainter({
    required this.amplitudes,
    required this.color,
    this.amplitudeCount,
    this.inactiveColor,
    this.progress,
    this.barWidth = 3.0,
    this.barSpacing = 2.0,
    this.minBarHeight = 2.0,
  });

  /// Normalized amplitude values (0.0–1.0).
  final List<double> amplitudes;

  /// Number of amplitude samples. Used as a repaint signal when the
  /// amplitudes list is a mutable growable list (same identity across
  /// appends). When null, falls back to identity check (#774).
  final int? amplitudeCount;

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
    // When amplitudeCount is provided, use it as the change signal
    // (growable mutable list — same identity across appends, #774).
    final amplitudesChanged = amplitudeCount != null
        ? amplitudeCount != oldDelegate.amplitudeCount
        : !identical(amplitudes, oldDelegate.amplitudes);
    return amplitudesChanged ||
        progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        inactiveColor != oldDelegate.inactiveColor;
  }
}
