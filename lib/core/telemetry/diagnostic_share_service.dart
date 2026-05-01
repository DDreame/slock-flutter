import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slock_app/core/telemetry/diagnostic_log_service.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

/// Result of a diagnostic share/export operation.
enum DiagnosticShareResult {
  /// The operation completed successfully.
  success,

  /// The operation was dismissed or cancelled by the user.
  dismissed,
}

/// Abstraction over clipboard, native share sheet, and file save
/// for diagnostic log bundles.
///
/// All methods accept pre-formatted text from [DiagnosticLogService.formatText].
abstract class DiagnosticShareService {
  /// Copies [text] to the system clipboard.
  Future<DiagnosticShareResult> copyToClipboard(String text);

  /// Opens the platform native share sheet with [text].
  Future<DiagnosticShareResult> shareText(String text);

  /// Saves [text] to a file in the app's documents directory.
  /// Returns the path of the written file.
  Future<String> saveToFile(String text, {String? filename});
}

/// Default implementation backed by real platform APIs.
class DefaultDiagnosticShareService implements DiagnosticShareService {
  @override
  Future<DiagnosticShareResult> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    return DiagnosticShareResult.success;
  }

  @override
  Future<DiagnosticShareResult> shareText(String text) async {
    final result = await Share.share(
      text,
      subject: 'Slock Diagnostics',
    );
    if (result.status == ShareResultStatus.dismissed) {
      return DiagnosticShareResult.dismissed;
    }
    return DiagnosticShareResult.success;
  }

  @override
  Future<String> saveToFile(String text, {String? filename}) async {
    final dir = await getApplicationDocumentsDirectory();
    final ts =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final name = filename ?? 'slock-diagnostics-$ts.txt';
    final file = File('${dir.path}/$name');
    await file.writeAsString(text);
    return file.path;
  }
}

final diagnosticShareServiceProvider = Provider<DiagnosticShareService>((ref) {
  return DefaultDiagnosticShareService();
});

final diagnosticLogServiceProvider = Provider<DiagnosticLogService>((ref) {
  final collector = ref.watch(diagnosticsCollectorProvider);
  return DiagnosticLogService(collector: collector);
});
