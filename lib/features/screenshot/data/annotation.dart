import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Types of annotation tools available in the screenshot editor.
enum AnnotationTool { freehand, text, arrow }

/// A single annotation drawn on the screenshot canvas.
@immutable
sealed class Annotation {
  const Annotation({required this.color});

  /// The color used for this annotation.
  final Color color;
}

/// A freehand drawing stroke (series of points).
@immutable
class FreehandAnnotation extends Annotation {
  const FreehandAnnotation({
    required super.color,
    required this.points,
    this.strokeWidth = 3.0,
  });

  /// The points that make up this stroke, in logical coordinates.
  final List<Offset> points;

  /// The width of the stroke.
  final double strokeWidth;

  /// Returns a new [FreehandAnnotation] with the given [point] appended.
  FreehandAnnotation addPoint(Offset point) {
    return FreehandAnnotation(
      color: color,
      points: [...points, point],
      strokeWidth: strokeWidth,
    );
  }
}

/// A text annotation placed at a specific position.
@immutable
class TextAnnotation extends Annotation {
  const TextAnnotation({
    required super.color,
    required this.position,
    required this.text,
    this.fontSize = 16.0,
  });

  /// The top-left position of the text in logical coordinates.
  final Offset position;

  /// The text content.
  final String text;

  /// The font size.
  final double fontSize;
}

/// An arrow annotation drawn from [start] to [end].
@immutable
class ArrowAnnotation extends Annotation {
  const ArrowAnnotation({
    required super.color,
    required this.start,
    required this.end,
    this.strokeWidth = 3.0,
  });

  /// The starting point of the arrow.
  final Offset start;

  /// The ending point (arrowhead) of the arrow.
  final Offset end;

  /// The width of the arrow shaft.
  final double strokeWidth;
}
