import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/telemetry/crash_detected_provider.dart';
import 'package:slock_app/core/telemetry/crash_recovery_dialog.dart';
import 'package:slock_app/core/telemetry/diagnostic_share_sheet.dart';

/// Wraps the app content and shows [CrashRecoveryDialog] once when a
/// previous crash is detected and the app has finished bootstrapping.
///
/// Place this inside the [MaterialApp.builder] so it has access to a
/// [Navigator] context and sits above all routes.
class CrashRecoveryWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const CrashRecoveryWrapper({super.key, required this.child});

  @override
  ConsumerState<CrashRecoveryWrapper> createState() =>
      _CrashRecoveryWrapperState();
}

class _CrashRecoveryWrapperState extends ConsumerState<CrashRecoveryWrapper> {
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(appReadyProvider, (prev, next) {
      _maybeShowDialog();
    });
    ref.listen<bool>(crashDetectedProvider, (prev, next) {
      _maybeShowDialog();
    });
    return widget.child;
  }

  void _maybeShowDialog() {
    if (_dialogShown) return;
    final appReady = ref.read(appReadyProvider);
    final crashDetected = ref.read(crashDetectedProvider);
    if (!appReady || !crashDetected) return;

    _dialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final wantsExport = await CrashRecoveryDialog.show(context);

      // Reset crash-detected state to match cleared secure storage.
      ref.read(crashDetectedProvider.notifier).state = false;

      if (wantsExport == true && mounted) {
        await DiagnosticShareSheet.show(context);
      }
    });
  }
}
