import 'package:flutter/material.dart';

/// Shared loading indicator widget.
///
/// Wraps [CircularProgressIndicator] in a configurable [SizedBox] with
/// optional centering. Replaces 70+ inline `CircularProgressIndicator`
/// instances across the codebase (#642).
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    this.size = 24,
    this.color,
    this.centered = true,
    super.key,
  });

  /// Width and height of the indicator box.
  final double size;

  /// Override color. When null, inherits from theme.
  final Color? color;

  /// Whether to wrap in a [Center] widget. Defaults to true for
  /// full-screen loading states; set to false for inline spinners.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: size < 24 ? 2 : 3,
        color: color,
      ),
    );

    if (centered) return Center(child: indicator);
    return indicator;
  }
}
