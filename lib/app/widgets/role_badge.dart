import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';

/// Small colored pill badge for roles (Admin, AI, etc.).
///
/// Background is a tinted (low-opacity) version of [color]; text uses
/// the full [color] for contrast.
class RoleBadge extends StatelessWidget {
  const RoleBadge({
    super.key,
    required this.label,
    required this.color,
  });

  /// Badge text (e.g. "Admin", "AI", "Mod").
  final String label;

  /// Accent color used for text and tinted background.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('role-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
