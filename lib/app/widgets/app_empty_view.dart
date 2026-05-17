import 'package:flutter/material.dart';

/// Shared empty-state widget used across all features.
///
/// Replaces feature-specific private empty-state widgets with a
/// consistent empty UI: centered icon + title + optional subtitle.
///
/// Phase B will flesh out the full layout. This placeholder ensures
/// Phase A tests compile.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    required this.icon,
    required this.title,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    // Phase B: implement full empty-state layout.
    throw UnimplementedError('AppEmptyView not yet implemented');
  }
}
