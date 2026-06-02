import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// Channel filter bar extracted from tasks_page.dart.
// ---------------------------------------------------------------------------

// -- Filter chip Z2 spec tokens --
const double kTaskFilterChipHeight = 32.0;
const double kTaskFilterChipRadius = 16.0;
const double kTaskFilterChipHorizontalPadding = 14.0;
const double kTaskFilterChipFontSize = 13.0;
const FontWeight kTaskFilterChipFontWeight = FontWeight.w500;
const double kTaskFilterChipGap = 8.0;

/// Hoisted border radius for TaskFilterChip.
final taskFilterChipBorderRadius = BorderRadius.circular(kTaskFilterChipRadius);

class TasksChannelFilterBar extends StatelessWidget {
  const TasksChannelFilterBar({
    super.key,
    required this.channelIds,
    required this.channelName,
    required this.selectedChannelId,
    required this.colors,
    required this.onSelected,
  });

  final List<String> channelIds;
  final String Function(String) channelName;
  final String? selectedChannelId;
  final AppColors colors;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('task-filter-bar'),
      padding: const EdgeInsets.only(
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
        bottom: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            TaskFilterChip(
              key: const ValueKey('task-filter-all'),
              label: context.l10n.tasksFilterAll,
              isSelected: selectedChannelId == null,
              colors: colors,
              onTap: () => onSelected(null),
            ),
            for (final id in channelIds) ...[
              const SizedBox(width: kTaskFilterChipGap),
              TaskFilterChip(
                key: ValueKey('task-filter-$id'),
                label: channelName(id),
                isSelected: selectedChannelId == id,
                colors: colors,
                onTap: () => onSelected(id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TaskFilterChip extends StatelessWidget {
  const TaskFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  static final _borderRadius = taskFilterChipBorderRadius;

  final String label;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: _borderRadius,
          child: Container(
            height: kTaskFilterChipHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: kTaskFilterChipHorizontalPadding,
            ),
            decoration: BoxDecoration(
              color: isSelected ? colors.primary : colors.surfaceAlt,
              borderRadius: _borderRadius,
              border: isSelected ? null : Border.all(color: colors.border),
            ),
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: kTaskFilterChipFontSize,
                  fontWeight: kTaskFilterChipFontWeight,
                  color: isSelected
                      ? colors.primaryForeground
                      : colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
