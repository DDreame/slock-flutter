import 'package:flutter/material.dart';

/// An action item displayed in [showListActionSheet].
class ListActionItem {
  const ListActionItem({
    required this.key,
    required this.label,
    required this.icon,
    this.isDestructive = false,
  });

  /// ValueKey identifier for the ListTile.
  final String key;

  /// Display label.
  final String label;

  /// Leading icon.
  final IconData icon;

  /// If true, the item is styled with the error/destructive color.
  final bool isDestructive;
}

/// Shows a standardized bottom sheet with a list of actions.
///
/// Fires [onOpenHaptic] when the sheet opens for tactile confirmation.
///
/// Returns the [ListActionItem.key] of the selected action, or `null` if
/// the sheet was dismissed without selection.
Future<String?> showListActionSheet({
  required BuildContext context,
  required List<ListActionItem> actions,
  String? title,
  Future<void> Function()? onOpenHaptic,
}) async {
  onOpenHaptic?.call();

  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              for (final action in actions)
                ListTile(
                  key: ValueKey(action.key),
                  leading: Icon(
                    action.icon,
                    color:
                        action.isDestructive ? theme.colorScheme.error : null,
                  ),
                  title: Text(
                    action.label,
                    style: action.isDestructive
                        ? TextStyle(color: theme.colorScheme.error)
                        : null,
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(action.key),
                ),
            ],
          ),
        ),
      );
    },
  );
}
