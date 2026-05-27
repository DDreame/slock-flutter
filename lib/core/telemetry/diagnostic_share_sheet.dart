import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/telemetry/diagnostic_log_service.dart';
import 'package:slock_app/core/telemetry/diagnostic_share_service.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/l10n/l10n.dart';

// --- Component-level sizing constants ---

/// Width of the bottom sheet drag handle.
const double _kHandleWidth = 36;

/// Height of the bottom sheet drag handle.
const double _kHandleHeight = 4;

/// Border radius of the drag handle pill.
const double _kHandleRadius = 2;

/// Icon size for action tile leading icons.
const double _kActionIconSize = 22;

/// Icon size for action tile trailing chevron.
const double _kChevronSize = 20;

/// Size of the inline loading spinner.
const double _kLoadingSize = 20;

/// Stroke width of the loading spinner.
const double _kLoadingStroke = 2;

/// A bottom sheet that lets users copy, share, or save diagnostic logs.
///
/// Builds a [DiagnosticBundle] from the current [DiagnosticLogService],
/// formats it as text, and provides three actions:
/// - **Copy** — copies to clipboard
/// - **Share** — opens the platform share sheet via share_plus
/// - **Save** — writes to the app documents directory
class DiagnosticShareSheet extends ConsumerStatefulWidget {
  const DiagnosticShareSheet({
    super.key,
    this.context,
    this.maxEntries,
  });

  /// Optional device/app context to include in the bundle header.
  final DiagnosticContext? context;

  /// Optional limit on the number of entries to include.
  final int? maxEntries;

  /// Shows the share sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    DiagnosticContext? diagnosticContext,
    int? maxEntries,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (_) => DiagnosticShareSheet(
        context: diagnosticContext,
        maxEntries: maxEntries,
      ),
    );
  }

  @override
  ConsumerState<DiagnosticShareSheet> createState() =>
      _DiagnosticShareSheetState();
}

class _DiagnosticShareSheetState extends ConsumerState<DiagnosticShareSheet> {
  String? _statusMessage;
  bool _isBusy = false;

  String _buildText() {
    final logService = ref.read(diagnosticLogServiceProvider);
    final bundle = logService.buildBundle(
      context: widget.context,
      maxEntries: widget.maxEntries,
    );
    return logService.formatText(bundle);
  }

  Future<void> _handleCopy() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _statusMessage = null;
    });
    try {
      final text = _buildText();
      final shareService = ref.read(diagnosticShareServiceProvider);
      await shareService.copyToClipboard(text);
      if (!mounted) return;
      setState(() {
        _statusMessage = context.l10n.diagCopied;
        _isBusy = false;
      });
    } on Exception catch (e) {
      ref.read(diagnosticsCollectorProvider).error(
            'DiagnosticShareSheet',
            'Copy to clipboard failed: $e',
          );
      if (!mounted) return;
      setState(() {
        _statusMessage = context.l10n.diagCopyFailed;
        _isBusy = false;
      });
    }
  }

  Future<void> _handleShare() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _statusMessage = null;
    });
    try {
      final text = _buildText();
      final shareService = ref.read(diagnosticShareServiceProvider);
      final result = await shareService.shareText(text);
      if (!mounted) return;
      setState(() {
        _statusMessage = result == DiagnosticShareResult.success
            ? context.l10n.diagShared
            : null;
        _isBusy = false;
      });
    } on Exception catch (e) {
      ref.read(diagnosticsCollectorProvider).error(
            'DiagnosticShareSheet',
            'Share failed: $e',
          );
      if (!mounted) return;
      setState(() {
        _statusMessage = context.l10n.diagShareFailed;
        _isBusy = false;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _statusMessage = null;
    });
    try {
      final text = _buildText();
      final shareService = ref.read(diagnosticShareServiceProvider);
      final path = await shareService.saveToFile(text);
      if (!mounted) return;
      setState(() {
        _statusMessage = context.l10n.diagSaved(path);
        _isBusy = false;
      });
    } on Exception catch (e) {
      ref.read(diagnosticsCollectorProvider).error(
            'DiagnosticShareSheet',
            'Save to file failed: $e',
          );
      if (!mounted) return;
      setState(() {
        _statusMessage = context.l10n.diagSaveFailed;
        _isBusy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Drag handle ---
            Center(
              child: Container(
                key: const ValueKey('share-sheet-handle'),
                width: _kHandleWidth,
                height: _kHandleHeight,
                decoration: BoxDecoration(
                  color: colors.textTertiary,
                  borderRadius: BorderRadius.circular(_kHandleRadius),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // --- Title ---
            Text(
              context.l10n.diagExportTitle,
              key: const ValueKey('share-sheet-title'),
              style: AppTypography.title.copyWith(color: colors.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.diagExportSubtitle,
              key: const ValueKey('share-sheet-subtitle'),
              style: AppTypography.body.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // --- Action buttons ---
            _ActionTile(
              key: const ValueKey('share-sheet-copy'),
              icon: Icons.copy,
              label: context.l10n.diagCopyToClipboard,
              colors: colors,
              enabled: !_isBusy,
              onTap: _handleCopy,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              key: const ValueKey('share-sheet-share'),
              icon: Icons.share,
              label: context.l10n.diagShare,
              colors: colors,
              enabled: !_isBusy,
              onTap: _handleShare,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              key: const ValueKey('share-sheet-save'),
              icon: Icons.save_alt,
              label: context.l10n.diagSaveToFile,
              colors: colors,
              enabled: !_isBusy,
              onTap: _handleSave,
            ),

            // --- Status message ---
            if (_statusMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                _statusMessage!,
                key: const ValueKey('share-sheet-status'),
                style: AppTypography.label.copyWith(color: colors.primary),
                textAlign: TextAlign.center,
              ),
            ],

            // --- Loading indicator ---
            if (_isBusy) ...[
              const SizedBox(height: AppSpacing.lg),
              const Center(
                key: ValueKey('share-sheet-loading'),
                child: SizedBox(
                  width: _kLoadingSize,
                  height: _kLoadingSize,
                  child:
                      CircularProgressIndicator(strokeWidth: _kLoadingStroke),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.colors,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final AppColors colors;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled ? colors.primary : colors.textTertiary,
                size: _kActionIconSize,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    color: enabled ? colors.text : colors.textTertiary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colors.textTertiary,
                size: _kChevronSize,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
