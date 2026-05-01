import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/telemetry/diagnostic_log_service.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

/// Icon size for the warning indicator at the top of the screen.
const double _kWarningIconSize = 48;

class FatalBootstrapScreen extends StatelessWidget {
  const FatalBootstrapScreen({super.key, required this.error});

  final Object error;

  bool get _isMissingDartDefine =>
      error.toString().contains('Missing required dart-define');

  String get _friendlyTitle => 'Unable to Start';

  String get _friendlyBody => _isMissingDartDefine
      ? 'The app is missing required configuration and cannot start. '
          'This usually means it was built without the necessary environment settings.'
      : 'Something went wrong during startup. '
          'Please try restarting the app.';

  String get _friendlyHint => _isMissingDartDefine
      ? 'If you are a developer, ensure all required --dart-define values '
          'are provided at build time.'
      : 'If the problem persists, reinstall the app or contact support.';

  /// Builds a diagnostics payload using [DiagnosticLogService] format.
  ///
  /// Creates a temporary [DiagnosticsCollector] with the bootstrap error
  /// as a single entry, then formats it through the standard service
  /// pipeline so the output matches the canonical log format.
  String get _diagnosticsPayload {
    final collector = DiagnosticsCollector();
    collector.error(
      'bootstrap',
      error.toString(),
      metadata: {
        'errorType': error.runtimeType.toString(),
      },
    );
    final service = DiagnosticLogService(collector: collector);
    final bundle = service.buildBundle(
      context: const DiagnosticContext(
        appVersion: null,
        platform: null,
        locale: null,
      ),
    );
    return service.formatText(bundle);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Builder(
        builder: (context) {
          final colors = Theme.of(context).extension<AppColors>()!;
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: _kWarningIconSize,
                      color: colors.warning,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _friendlyTitle,
                      style:
                          AppTypography.headline.copyWith(color: colors.text),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _friendlyBody,
                      style: AppTypography.body.copyWith(color: colors.text),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _friendlyHint,
                      style: AppTypography.bodySmall
                          .copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _CopyDiagnosticsButton(
                      diagnosticsPayload: _diagnosticsPayload,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CopyDiagnosticsButton extends StatelessWidget {
  const _CopyDiagnosticsButton({required this.diagnosticsPayload});

  final String diagnosticsPayload;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('copy-diagnostics'),
      icon: const Icon(Icons.copy, size: 18),
      label: const Text('Copy diagnostics'),
      onPressed: () async {
        await Clipboard.setData(
          ClipboardData(text: diagnosticsPayload),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Diagnostics copied to clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }
}
