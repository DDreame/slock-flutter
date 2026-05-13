import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

/// Inline preview for CSV attachments (INV-ATTACH-1).
///
/// Fetches the CSV content from the attachment URL and renders the first
/// [_maxRows] rows as a scrollable [Table]. On error, shows a generic
/// file‑row fallback (INV-ATTACH-2).
class CsvPreviewWidget extends StatefulWidget {
  const CsvPreviewWidget({super.key, required this.attachment});

  final MessageAttachment attachment;

  @override
  State<CsvPreviewWidget> createState() => _CsvPreviewWidgetState();
}

class _CsvPreviewWidgetState extends State<CsvPreviewWidget> {
  static const _maxRows = 10;

  List<List<String>>? _rows;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCsv();
  }

  Future<void> _fetchCsv() async {
    final url = widget.attachment.url;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _error = 'No download URL');
      return;
    }
    try {
      final response = await Dio().get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      if (!mounted) return;
      final content = response.data ?? '';
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty);
      final rows = <List<String>>[];
      for (final line in lines.take(_maxRows)) {
        rows.add(_splitCsvLine(line));
      }
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load CSV';
        _loading = false;
      });
    }
  }

  /// Simple CSV line splitter — splits on commas, respecting double-quoted
  /// fields. Does not handle escaped quotes within quoted fields (edge case).
  List<String> _splitCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    fields.add(buffer.toString().trim());
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _FallbackRow(
        key: ValueKey('csv-fallback-${widget.attachment.name}'),
        attachment: widget.attachment,
        errorHint: _error!,
      );
    }

    if (_loading) {
      return Padding(
        key: ValueKey('csv-loading-${widget.attachment.name}'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              widget.attachment.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final rows = _rows!;
    if (rows.isEmpty) {
      return _FallbackRow(
        key: ValueKey('csv-empty-${widget.attachment.name}'),
        attachment: widget.attachment,
        errorHint: 'Empty CSV',
      );
    }

    final maxCols =
        rows.fold<int>(0, (max, row) => row.length > max ? row.length : max);
    final theme = Theme.of(context);

    return Column(
      key: ValueKey('csv-preview-${widget.attachment.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.attachment.name,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(
              color: theme.colorScheme.outlineVariant,
              width: 0.5,
            ),
            children: [
              for (var i = 0; i < rows.length; i++)
                TableRow(
                  decoration: i == 0
                      ? BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                        )
                      : null,
                  children: [
                    for (var j = 0; j < maxCols; j++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          j < rows[i].length ? rows[i][j] : '',
                          style: i == 0
                              ? theme.textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)
                              : theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Minimal fallback row shown when preview fails (INV-ATTACH-2).
class _FallbackRow extends StatelessWidget {
  const _FallbackRow({
    super.key,
    required this.attachment,
    required this.errorHint,
  });

  final MessageAttachment attachment;
  final String errorHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.attach_file,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            attachment.name,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          errorHint,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}
