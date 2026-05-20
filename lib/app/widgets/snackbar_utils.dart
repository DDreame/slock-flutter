import 'package:flutter/material.dart';

/// Shows a snackbar with the given [message], dismissing any existing one.
///
/// When [isError] is true the snackbar uses the theme's error color.
/// Replaces the repeated `ScaffoldMessenger.of(context)..hideCurrentSnackBar()
/// ..showSnackBar(...)` pattern across 28 pages (#642).
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
    ),
  );
}

/// Shows a snackbar with a [message] and a tappable [actionLabel] button.
void showAppSnackBarWithAction(
  BuildContext context,
  String message, {
  required String actionLabel,
  required VoidCallback onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: actionLabel,
        onPressed: onAction,
      ),
    ),
  );
}
