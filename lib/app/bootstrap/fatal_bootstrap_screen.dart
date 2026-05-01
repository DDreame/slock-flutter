import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slock_app/core/telemetry/diagnostic_log_service.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

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
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48),
                const SizedBox(height: 16),
                Text(
                  _friendlyTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _friendlyBody,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  _friendlyHint,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                _CopyDiagnosticsButton(
                  diagnosticsPayload: _diagnosticsPayload,
                ),
              ],
            ),
          ),
        ),
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
        await Clipboard.setData(ClipboardData(text: diagnosticsPayload));
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
