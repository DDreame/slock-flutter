import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';

/// Custom painter that renders annotations on top of a screenshot image.
///
/// When [displayScale] and [displayOffset] are provided (display mode), the
/// painter applies an image→display transform so annotations stored in
/// image-pixel coordinates appear at the correct on-screen positions.
///
/// When omitted (export mode), annotations are painted in raw image-pixel
/// coordinates directly onto the full-resolution canvas.
class AnnotationPainter extends CustomPainter {
  const AnnotationPainter({
    required this.annotations,
    this.activeStroke,
    this.displayScale,
    this.displayOffset,
  });

  /// Completed annotations to render.
  final List<Annotation> annotations;

  /// The currently in-progress freehand stroke (live feedback while drawing).
  ///
  /// Note: the active stroke is in **display** coordinates (raw gesture input)
  /// and is painted *after* the canvas transform is reset, so it tracks the
  /// finger position directly. Committed annotations are in image coordinates.
  final FreehandAnnotation? activeStroke;

  /// Scale factor from image-pixel space to display-logical space.
  /// If null, no transform is applied (export mode).
  final double? displayScale;

  /// Offset from the top-left of the painting area to the top-left of the
  /// displayed image (accounts for `BoxFit.contain` letterboxing).
  /// If null, no transform is applied (export mode).
  final Offset? displayOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final hasTransform = displayScale != null && displayOffset != null;

    if (hasTransform) {
      canvas.save();
      canvas.translate(displayOffset!.dx, displayOffset!.dy);
      canvas.scale(displayScale!);
    }

    for (final annotation in annotations) {
      _paintAnnotation(canvas, annotation);
    }

    if (hasTransform) {
      canvas.restore();
    }

    // Active stroke is painted in display coordinates (no transform).
    if (activeStroke != null) {
      _paintAnnotation(canvas, activeStroke!);
    }
  }

  void _paintAnnotation(Canvas canvas, Annotation annotation) {
    switch (annotation) {
      case FreehandAnnotation(:final points, :final color, :final strokeWidth):
        _paintFreehand(canvas, points, color, strokeWidth);
      case TextAnnotation(
          :final position,
          :final text,
          :final color,
          :final fontSize
        ):
        _paintText(canvas, position, text, color, fontSize);
      case ArrowAnnotation(
          :final start,
          :final end,
          :final color,
          :final strokeWidth
        ):
        _paintArrow(canvas, start, end, color, strokeWidth);
    }
  }

  void _paintFreehand(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double strokeWidth,
  ) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  void _paintText(
    Canvas canvas,
    Offset position,
    String text,
    Color color,
    double fontSize,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, position);
  }

  void _paintArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    double strokeWidth,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw the shaft.
    canvas.drawLine(start, end, paint);

    // Draw the arrowhead.
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const headLength = 15.0;
    const headAngle = math.pi / 6; // 30 degrees

    final head1 = Offset(
      end.dx - headLength * math.cos(angle - headAngle),
      end.dy - headLength * math.sin(angle - headAngle),
    );
    final head2 = Offset(
      end.dx - headLength * math.cos(angle + headAngle),
      end.dy - headLength * math.sin(angle + headAngle),
    );

    final headPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.fill;

    final headPath = ui.Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(head1.dx, head1.dy)
      ..lineTo(head2.dx, head2.dy)
      ..close();
    canvas.drawPath(headPath, headPaint);
  }

  @override
  bool shouldRepaint(AnnotationPainter oldDelegate) {
    return annotations != oldDelegate.annotations ||
        activeStroke != oldDelegate.activeStroke ||
        displayScale != oldDelegate.displayScale ||
        displayOffset != oldDelegate.displayOffset;
  }
}
