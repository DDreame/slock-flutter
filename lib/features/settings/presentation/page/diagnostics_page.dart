import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/notifications/foreground_service_lifecycle_binding.dart';
import 'package:slock_app/core/telemetry/diagnostic_share_sheet.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Page that displays diagnostic log entries with filtering and export.
///
/// Reads entries from [DiagnosticsCollector] and renders them in a
/// reverse-chronological list (newest first). Filter chips allow
/// narrowing by [DiagnosticsLevel]. A FAB opens [DiagnosticShareSheet]
/// for copy/share/save export.
class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends ConsumerState<DiagnosticsPage> {
  DiagnosticsLevel? _activeFilter;

  List<DiagnosticsEntry> _filteredEntries(List<DiagnosticsEntry> all) {
    final filtered = _activeFilter == null
        ? all
        : all.where((e) => e.level == _activeFilter);
    // Reverse so newest entries appear first.
    return filtered.toList().reversed.toList();
  }

  Color _levelColor(DiagnosticsLevel level, AppColors colors) {
    return switch (level) {
      DiagnosticsLevel.info => colors.primary,
      DiagnosticsLevel.warning => colors.warning,
      DiagnosticsLevel.error => colors.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final collector = ref.watch(diagnosticsCollectorProvider);
    final workerDiagnostics = ref.watch(backgroundWorkerDiagnosticsProvider);
    final allEntries = collector.entries;
    final entries = _filteredEntries(allEntries);
    final colors = Theme.of(context).extension<AppColors>()!;

    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsDiagnosticsPageTitle),
            Text(
              l10n.settingsDiagnosticsEntryCount(allEntries.length),
              key: const ValueKey('diagnostics-entry-count'),
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('diagnostics-export-fab'),
        tooltip: l10n.diagnosticsExportFabTooltip,
        onPressed: () => DiagnosticShareSheet.show(context),
        child: const Icon(Icons.ios_share),
      ),
      body: Column(
        children: [
          _BackgroundWorkerDiagnosticsCard(
            diagnostics: workerDiagnostics,
            colors: colors,
          ),
          const Divider(height: 1),

          // --- Filter chips ---
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                _FilterChipWidget(
                  key: const ValueKey('diagnostics-filter-all'),
                  label: l10n.settingsDiagnosticsFilterAll,
                  selected: _activeFilter == null,
                  onSelected: (_) => setState(() => _activeFilter = null),
                  colors: colors,
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChipWidget(
                  key: const ValueKey('diagnostics-filter-info'),
                  label: l10n.settingsDiagnosticsFilterInfo,
                  selected: _activeFilter == DiagnosticsLevel.info,
                  onSelected: (_) =>
                      setState(() => _activeFilter = DiagnosticsLevel.info),
                  colors: colors,
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChipWidget(
                  key: const ValueKey('diagnostics-filter-warning'),
                  label: l10n.settingsDiagnosticsFilterWarning,
                  selected: _activeFilter == DiagnosticsLevel.warning,
                  onSelected: (_) =>
                      setState(() => _activeFilter = DiagnosticsLevel.warning),
                  colors: colors,
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChipWidget(
                  key: const ValueKey('diagnostics-filter-error'),
                  label: l10n.settingsDiagnosticsFilterError,
                  selected: _activeFilter == DiagnosticsLevel.error,
                  onSelected: (_) =>
                      setState(() => _activeFilter = DiagnosticsLevel.error),
                  colors: colors,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // --- Entry list ---
          Expanded(
            child: entries.isEmpty
                ? Center(
                    key: const ValueKey('diagnostics-empty'),
                    child: Text(
                      l10n.settingsDiagnosticsEmpty,
                      style: AppTypography.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageHorizontal,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) => _DiagnosticsEntryTile(
                      entry: entries[index],
                      index: index,
                      levelColor: _levelColor(entries[index].level, colors),
                      colors: colors,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundWorkerDiagnosticsCard extends StatelessWidget {
  const _BackgroundWorkerDiagnosticsCard({
    required this.diagnostics,
    required this.colors,
  });

  final AsyncValue<Map<String, dynamic>?> diagnostics;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: Container(
        key: const ValueKey('background-worker-diagnostics'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: colors.border),
        ),
        child: diagnostics.when(
          loading: () => Text(
            context.l10n.settingsDiagnosticsWorkerLoading,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          error: (_, __) => Text(
            context.l10n.settingsDiagnosticsWorkerUnavailable,
            style: AppTypography.body.copyWith(color: colors.error),
          ),
          data: (snapshot) {
            if (snapshot == null) {
              return Text(
                context.l10n.settingsDiagnosticsWorkerNotRunning,
                style: AppTypography.body.copyWith(
                  color: colors.textSecondary,
                ),
              );
            }
            final items = <String>[
              'service=${snapshot['isServiceAlive']}',
              'socket=${snapshot['socketStatus']}',
              'auth=${snapshot['authStatus']}',
              'foreground=${snapshot['foregroundActive']}',
              'lastEvent=${snapshot['lastEventTime'] ?? 'none'}',
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.settingsDiagnosticsWorkerTitle,
                  style: AppTypography.body.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  items.join(' • '),
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterChipWidget extends StatelessWidget {
  const _FilterChipWidget({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.colors,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: colors.primaryLight,
      checkmarkColor: colors.primary,
      labelStyle: AppTypography.label.copyWith(
        color: selected ? colors.primary : colors.textSecondary,
      ),
    );
  }
}

class _DiagnosticsEntryTile extends StatefulWidget {
  const _DiagnosticsEntryTile({
    required this.entry,
    required this.index,
    required this.levelColor,
    required this.colors,
  });

  final DiagnosticsEntry entry;
  final int index;
  final Color levelColor;
  final AppColors colors;

  @override
  State<_DiagnosticsEntryTile> createState() => _DiagnosticsEntryTileState();
}

class _DiagnosticsEntryTileState extends State<_DiagnosticsEntryTile> {
  bool _expanded = false;

  bool get _hasMetadata =>
      widget.entry.metadata != null && widget.entry.metadata!.isNotEmpty;

  String _formatTimestamp(DateTime ts) {
    return '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}:'
        '${ts.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final colors = widget.colors;

    return Semantics(
      button: _hasMetadata,
      label: _hasMetadata ? context.l10n.diagnosticsEntryExpandSemantics : null,
      child: GestureDetector(
        onTap:
            _hasMetadata ? () => setState(() => _expanded = !_expanded) : null,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Level indicator dot
                  Container(
                    key: ValueKey('diagnostics-level-${widget.index}'),
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: widget.levelColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      entry.tag,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Timestamp
                  Text(
                    _formatTimestamp(entry.timestamp),
                    style: AppTypography.caption
                        .copyWith(color: colors.textTertiary),
                  ),
                  if (_hasMetadata) ...[
                    const Spacer(),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: colors.textTertiary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // Message
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  entry.message,
                  style: AppTypography.body.copyWith(color: colors.text),
                ),
              ),
              // Metadata (expanded)
              if (_expanded && _hasMetadata) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entry.metadata!.entries
                        .map(
                          (kv) => Text(
                            '${kv.key}: ${kv.value}',
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
