import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

// ---------------------------------------------------------------------------
// #508: Task status drag overlay — 4-box drop zone grid + success animation
//
// Shown as an OverlayEntry when a task is long-press dragged.
// Contains 4 DragTarget<TaskItem> zones (todo/in_progress/in_review/done).
// Current status zone is dimmed (opacity 0.4) with "Current" badge.
//
// On successful drop:
//   1. Transitions to success state (green check pop + "Moved to X")
//   2. AnimatedScale pop: 400ms Curves.elasticOut
//   3. FadeTransition dismiss: 600ms Curves.easeOut
//   4. HapticFeedback.successNotification
//   5. Calls onStatusAccepted after animation completes
// ---------------------------------------------------------------------------

/// Z2 design tokens — overlay geometry.
const double _kDropZoneGap = AppSpacing.md;
const double _kDropZoneRadius = AppSpacing.radiusLg;
const double _kHoverScale = 1.04;
const double _kCurrentZoneOpacity = 0.4;
const double _kBackdropBlur = 4;

/// Overlay-specific color tokens — always rendered on dark backdrop.
const Color _kOverlayText = Colors.white;
const Color _kOverlayTextMuted = Colors.white70;
const Color _kOverlayTextDimmed = Colors.white60;
const Color _kOverlayTextSubtle = Colors.white54;
const double _kBackdropAlpha = 0.5;
const double _kSurfaceAlpha = 0.12;
const double _kSurfaceHoverAlpha = 0.2;
const double _kSurfaceAccentAlpha = 0.15;
const double _kSurfaceBadgeAlpha = 0.1;
const double _kBorderAlpha = 0.3;
const double _kGlowAlpha = 0.15;
const double _kSuccessIconBgAlpha = 0.3;
const double _kStatusIconBgAlpha = 0.3;

/// Success animation timing.
const Duration _kSuccessPopDuration = Duration(milliseconds: 400);
const Duration _kSuccessFadeDuration = Duration(milliseconds: 600);

/// The 4 statuses available in the drag overlay.
const _kDragStatuses = ['todo', 'in_progress', 'in_review', 'done'];

class TaskStatusOverlay extends StatefulWidget {
  const TaskStatusOverlay({
    super.key,
    required this.currentStatus,
    required this.onStatusAccepted,
    this.onDropAccepted,
  });

  /// The current status of the task being dragged.
  final String currentStatus;

  /// Called after the success animation completes — triggers status update
  /// and overlay removal.
  final ValueChanged<String> onStatusAccepted;

  /// Called immediately when a drop is accepted (before animation starts).
  /// Use this to prevent premature overlay removal from [onDragEnd].
  final VoidCallback? onDropAccepted;

  @override
  State<TaskStatusOverlay> createState() => _TaskStatusOverlayState();
}

class _TaskStatusOverlayState extends State<TaskStatusOverlay>
    with SingleTickerProviderStateMixin {
  /// The status that was accepted, or null if still in grid/drag state.
  String? _acceptedStatus;

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    final totalDuration = _kSuccessPopDuration + _kSuccessFadeDuration;
    final popFraction =
        _kSuccessPopDuration.inMilliseconds / totalDuration.inMilliseconds;

    _controller = AnimationController(vsync: this, duration: totalDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _acceptedStatus != null) {
          widget.onStatusAccepted(_acceptedStatus!);
        }
      });

    // Pop: 0 → popFraction (400ms), elasticOut overshoots to ~1.15 naturally.
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, popFraction, curve: Curves.elasticOut),
      ),
    );

    // Fade: popFraction → 1.0 (600ms), easeOut.
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(popFraction, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDropAccepted(String status) {
    setState(() => _acceptedStatus = status);
    widget.onDropAccepted?.call();
    HapticFeedback.successNotification();
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark backdrop with blur.
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _kBackdropBlur,
                sigmaY: _kBackdropBlur,
              ),
              child: Container(
                color: Colors.black.withValues(alpha: _kBackdropAlpha),
              ),
            ),
          ),

          // Content: success state or grid.
          Center(
            child: _acceptedStatus != null
                ? _buildSuccessState(colors)
                : _buildGridState(colors),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Grid state (drop zone selection)
  // -------------------------------------------------------------------------

  Widget _buildGridState(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Drop to change status',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kOverlayText,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 2×2 grid of drop zones.
          SizedBox(
            width: 320,
            child: Wrap(
              spacing: _kDropZoneGap,
              runSpacing: _kDropZoneGap,
              children: [
                for (final status in _kDragStatuses)
                  _buildDropZone(status, colors),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl - AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: _kOverlayText.withValues(alpha: _kSurfaceAccentAlpha),
              borderRadius:
                  BorderRadius.circular(AppSpacing.xl - AppSpacing.xs),
            ),
            child: const Text(
              'Release outside boxes to cancel',
              style: TextStyle(
                fontSize: 12,
                color: _kOverlayTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropZone(String status, AppColors colors) {
    final isCurrent = status == widget.currentStatus;
    const zoneWidth = (320 - AppSpacing.md) / 2;

    Widget zone = DragTarget<TaskItem>(
      key: ValueKey('drop-zone-$status'),
      onWillAcceptWithDetails: (_) {
        if (!isCurrent) {
          HapticFeedback.selectionClick();
        }
        return !isCurrent;
      },
      onAcceptWithDetails: (_) {
        _onDropAccepted(status);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return _DropZoneBox(
          status: status,
          isCurrent: isCurrent,
          isHovering: isHovering,
          width: zoneWidth,
          colors: colors,
        );
      },
    );

    if (isCurrent) {
      zone = Opacity(
        opacity: _kCurrentZoneOpacity,
        child: zone,
      );
    }

    return zone;
  }

  // -------------------------------------------------------------------------
  // Success state (green check pop + "Moved to X" + fade dismiss)
  // -------------------------------------------------------------------------

  Widget _buildSuccessState(AppColors colors) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('drop-success-icon'),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.success.withValues(alpha: _kSuccessIconBgAlpha),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.check,
              color: colors.success,
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Moved to ${_statusLabel(_acceptedStatus!)}',
            key: const ValueKey('drop-success-text'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _kOverlayText,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drop zone visual box
// ---------------------------------------------------------------------------

class _DropZoneBox extends StatelessWidget {
  const _DropZoneBox({
    required this.status,
    required this.isCurrent,
    required this.isHovering,
    required this.width,
    required this.colors,
  });

  final String status;
  final bool isCurrent;
  final bool isHovering;
  final double width;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: width,
      height: 120,
      transform: isHovering
          ? (Matrix4.identity()
            ..scaleByDouble(_kHoverScale, _kHoverScale, _kHoverScale, 1.0))
          : Matrix4.identity(),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kOverlayText.withValues(
          alpha: isHovering ? _kSurfaceHoverAlpha : _kSurfaceAlpha,
        ),
        borderRadius: BorderRadius.circular(_kDropZoneRadius),
        border: Border.all(
          color: _kOverlayText.withValues(
            alpha: isHovering ? 1.0 : _kBorderAlpha,
          ),
          width: 2,
        ),
        boxShadow: isHovering
            ? [
                BoxShadow(
                  color: _kOverlayText.withValues(alpha: _kGlowAlpha),
                  blurRadius: AppSpacing.xl,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatusIcon(status: status, colors: colors),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _statusLabel(status),
            style: TextStyle(
              fontSize: isHovering ? 14 : 13,
              fontWeight: FontWeight.w600,
              color: _kOverlayText,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (isCurrent)
            Container(
              key: const ValueKey('drop-zone-current-badge'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: _kOverlayText.withValues(alpha: _kSurfaceBadgeAlpha),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Text(
                'Current',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _kOverlayTextSubtle,
                ),
              ),
            )
          else
            Text(
              isHovering ? 'Release to move here' : _statusDescription(status),
              style: TextStyle(
                fontSize: 11,
                color: isHovering
                    ? _kOverlayText.withValues(alpha: 0.8)
                    : _kOverlayTextDimmed,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status icon
// ---------------------------------------------------------------------------

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.colors});

  final String status;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _statusIconBackground(status, colors),
      ),
      alignment: Alignment.center,
      child: Text(
        _statusEmoji(status),
        style: const TextStyle(fontSize: 20),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status helpers
// ---------------------------------------------------------------------------

String _statusLabel(String status) {
  return switch (status) {
    'todo' => 'Todo',
    'in_progress' => 'In Progress',
    'in_review' => 'In Review',
    'done' => 'Done',
    _ => status,
  };
}

String _statusDescription(String status) {
  return switch (status) {
    'todo' => 'Not started',
    'in_progress' => 'Working on it',
    'in_review' => 'Needs review',
    'done' => 'Completed',
    _ => '',
  };
}

String _statusEmoji(String status) {
  return switch (status) {
    'todo' => '○',
    'in_progress' => '▶',
    'in_review' => '👁',
    'done' => '✓',
    _ => '○',
  };
}

Color _statusIconBackground(String status, AppColors colors) {
  return switch (status) {
    'todo' => colors.textTertiary.withValues(alpha: _kStatusIconBgAlpha),
    'in_progress' => colors.primary.withValues(alpha: _kStatusIconBgAlpha),
    'in_review' => colors.warning.withValues(alpha: _kStatusIconBgAlpha),
    'done' => colors.success.withValues(alpha: _kStatusIconBgAlpha),
    _ => colors.textTertiary.withValues(alpha: _kStatusIconBgAlpha),
  };
}
