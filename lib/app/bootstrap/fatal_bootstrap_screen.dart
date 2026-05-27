import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/telemetry/diagnostic_log_service.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Icon size for the warning indicator at the top of the screen.
const double _kWarningIconSize = 48;

class FatalBootstrapScreen extends StatelessWidget {
  const FatalBootstrapScreen({super.key, required this.error});

  final Object error;

  bool get _isMissingDartDefine =>
      error.toString().contains('Missing required dart-define');

  /// Builds a diagnostics payload using [DiagnosticLogService] format.
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final colors = Theme.of(context).extension<AppColors>()!;
          final l10n = context.l10n;
          final friendlyTitle = l10n.fatalTitle;
          final friendlyBody = _isMissingDartDefine
              ? l10n.fatalBodyMissingConfig
              : l10n.fatalBodyGeneric;
          final friendlyHint = _isMissingDartDefine
              ? l10n.fatalHintDeveloper
              : l10n.fatalHintGeneric;
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
                      friendlyTitle,
                      style:
                          AppTypography.headline.copyWith(color: colors.text),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      friendlyBody,
                      style: AppTypography.body.copyWith(color: colors.text),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      friendlyHint,
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
      label: Text(context.l10n.fatalCopyDiagnostics),
      onPressed: () async {
        await Clipboard.setData(
          ClipboardData(text: diagnosticsPayload),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.fatalDiagnosticsCopied),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }
}
