import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/telemetry/diagnostic_share_sheet.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

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
    final allEntries = collector.entries;
    final entries = _filteredEntries(allEntries);
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Diagnostics'),
            Text(
              '${allEntries.length} ${allEntries.length == 1 ? 'entry' : 'entries'}',
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
        onPressed: () => DiagnosticShareSheet.show(context),
        child: const Icon(Icons.ios_share),
      ),
      body: Column(
        children: [
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
                  label: 'All',
                  selected: _activeFilter == null,
                  onSelected: (_) => setState(() => _activeFilter = null),
                  colors: colors,
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChipWidget(
                  key: const ValueKey('diagnostics-filter-info'),
                  label: 'Info',
                  selected: _activeFilter == DiagnosticsLevel.info,
                  onSelected: (_) =>
                      setState(() => _activeFilter = DiagnosticsLevel.info),
                  colors: colors,
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChipWidget(
                  key: const ValueKey('diagnostics-filter-warning'),
                  label: 'Warning',
                  selected: _activeFilter == DiagnosticsLevel.warning,
                  onSelected: (_) =>
                      setState(() => _activeFilter = DiagnosticsLevel.warning),
                  colors: colors,
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChipWidget(
                  key: const ValueKey('diagnostics-filter-error'),
                  label: 'Error',
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
                      'No diagnostic entries',
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

    return GestureDetector(
      onTap: _hasMetadata ? () => setState(() => _expanded = !_expanded) : null,
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
    );
  }
}
