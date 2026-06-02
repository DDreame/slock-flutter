import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// Status helper functions extracted from tasks_page.dart.
// ---------------------------------------------------------------------------

/// Returns the Z3 status symbol for a given task status.
String taskStatusSymbol(String status) {
  return switch (status) {
    'todo' => '○',
    'in_progress' => '◐',
    'in_review' => '◑',
    'done' => '●',
    'closed' => '✕',
    _ => '○',
  };
}

/// Returns the color for a status symbol using [AppColors] tokens.
Color taskStatusColor(String status, AppColors colors) {
  return switch (status) {
    'todo' => colors.textTertiary,
    'in_progress' => colors.primary,
    'in_review' => colors.warning,
    'done' => colors.success,
    'closed' => colors.textTertiary,
    _ => colors.textTertiary,
  };
}

/// Returns the accessible label for a task status symbol.
///
/// Used for screen reader announcements on status indicators and
/// combined task row descriptions.
String taskStatusAccessibilityLabel(String status, BuildContext context) {
  final l10n = context.l10n;
  return switch (status) {
    'todo' => l10n.tasksAccessibilityTodo,
    'in_progress' => l10n.tasksAccessibilityInProgress,
    'in_review' => l10n.tasksAccessibilityInReview,
    'done' => l10n.tasksAccessibilityDone,
    'closed' => l10n.tasksAccessibilityClosed,
    _ => status,
  };
}
