import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

// ---------------------------------------------------------------------------
// #508: Task status drag overlay — 4-box drop zone grid
//
// Shown as an OverlayEntry when a task is long-press dragged.
// Contains 4 DragTarget<TaskItem> zones (todo/in_progress/in_review/done).
// Current status zone is dimmed (opacity 0.4) with "Current" badge.
// ---------------------------------------------------------------------------

/// Z2 design tokens.
const double _kDropZoneGap = 12;
const double _kDropZoneRadius = 16;
const double _kHoverScale = 1.04;
const double _kCurrentZoneOpacity = 0.4;
const double _kBackdropBlur = 4;

/// The 4 statuses available in the drag overlay.
const _kDragStatuses = ['todo', 'in_progress', 'in_review', 'done'];

class TaskStatusOverlay extends StatelessWidget {
  const TaskStatusOverlay({
    super.key,
    required this.currentStatus,
    required this.onStatusAccepted,
  });

  /// The current status of the task being dragged.
  final String currentStatus;

  /// Called when the task is dropped on a non-current zone.
  final ValueChanged<String> onStatusAccepted;

  @override
  Widget build(BuildContext context) {
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
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),

          // Centered content.
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Drop to change status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2×2 grid of drop zones.
                  SizedBox(
                    width: 320,
                    child: Wrap(
                      spacing: _kDropZoneGap,
                      runSpacing: _kDropZoneGap,
                      children: [
                        for (final status in _kDragStatuses)
                          _buildDropZone(status),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Release outside boxes to cancel',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropZone(String status) {
    final isCurrent = status == currentStatus;
    const zoneWidth = (320 - _kDropZoneGap) / 2;

    Widget zone = DragTarget<TaskItem>(
      key: ValueKey('drop-zone-$status'),
      onWillAcceptWithDetails: (_) {
        if (!isCurrent) {
          HapticFeedback.selectionClick();
        }
        return !isCurrent;
      },
      onAcceptWithDetails: (_) {
        onStatusAccepted(status);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return _DropZoneBox(
          status: status,
          isCurrent: isCurrent,
          isHovering: isHovering,
          width: zoneWidth,
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
  });

  final String status;
  final bool isCurrent;
  final bool isHovering;
  final double width;

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
        color: isHovering
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(_kDropZoneRadius),
        border: Border.all(
          color:
              isHovering ? Colors.white : Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: isHovering
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.15),
                  blurRadius: 24,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatusIcon(status: status),
          const SizedBox(height: 8),
          Text(
            _statusLabel(status),
            style: TextStyle(
              fontSize: isHovering ? 14 : 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          if (isCurrent)
            Container(
              key: const ValueKey('drop-zone-current-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Current',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                ),
              ),
            )
          else
            Text(
              isHovering ? 'Release to move here' : _statusDescription(status),
              style: TextStyle(
                fontSize: 11,
                color: isHovering
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.white60,
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
  const _StatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _statusIconBackground(status),
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

Color _statusIconBackground(String status) {
  return switch (status) {
    'todo' => const Color(0xFF9CA3AF).withValues(alpha: 0.3),
    'in_progress' => const Color(0xFF3B82F6).withValues(alpha: 0.3),
    'in_review' => const Color(0xFFF59E0B).withValues(alpha: 0.3),
    'done' => const Color(0xFF10B981).withValues(alpha: 0.3),
    _ => const Color(0xFF9CA3AF).withValues(alpha: 0.3),
  };
}
