import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/telemetry/crash_marker_service.dart';
import 'package:slock_app/core/telemetry/diagnostic_share_sheet.dart';

/// A dialog shown on startup when a previous crash was detected.
///
/// Offers the user two choices:
/// - **Export Diagnostics** — opens [DiagnosticShareSheet] so the user
///   can copy/share/save the diagnostic log from the crashed session.
/// - **Continue** — dismisses the dialog and clears the crash marker.
class CrashRecoveryDialog extends ConsumerWidget {
  const CrashRecoveryDialog({super.key});

  /// Shows the crash recovery dialog as a modal.
  ///
  /// Returns `true` if the user chose to export diagnostics,
  /// `false` if they dismissed or chose to continue.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CrashRecoveryDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return AlertDialog(
      key: const ValueKey('crash-recovery-dialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            key: const ValueKey('crash-recovery-icon'),
            color: colors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'App Recovered',
              key: const ValueKey('crash-recovery-title'),
              style: AppTypography.title.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
      content: Text(
        'The app stopped unexpectedly during your last session. '
        'You can export diagnostic logs to help us investigate.',
        key: const ValueKey('crash-recovery-message'),
        style: AppTypography.body.copyWith(color: colors.textSecondary),
      ),
      actions: [
        TextButton(
          key: const ValueKey('crash-recovery-continue'),
          onPressed: () async {
            await ref.read(crashMarkerServiceProvider).clearCrashMarker();
            if (context.mounted) {
              Navigator.of(context).pop(false);
            }
          },
          child: Text(
            'Continue',
            style: AppTypography.label.copyWith(color: colors.textSecondary),
          ),
        ),
        FilledButton.icon(
          key: const ValueKey('crash-recovery-export'),
          onPressed: () async {
            await ref.read(crashMarkerServiceProvider).clearCrashMarker();
            if (context.mounted) {
              Navigator.of(context).pop(true);
              await DiagnosticShareSheet.show(context);
            }
          },
          icon: const Icon(Icons.upload_outlined),
          label: const Text('Export Diagnostics'),
        ),
      ],
    );
  }
}
