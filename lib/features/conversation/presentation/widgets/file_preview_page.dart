import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart'
    show attachmentRepositoryProvider;
import 'package:slock_app/features/conversation/data/conversation_repository.dart'
    show MessageAttachment;
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Set of MIME types treated as images.
const _imageMimeTypes = {
  'image/png',
  'image/jpeg',
  'image/jpg',
  'image/gif',
  'image/webp',
};

/// Full-screen file preview page that routes by MIME type:
/// - PDF → downloads to temp file, renders with native PDF viewer
/// - Image → InteractiveViewer with network image
/// - Other → file info card with "Open with…" button
class FilePreviewPage extends ConsumerStatefulWidget {
  const FilePreviewPage({super.key, required this.attachment});

  final MessageAttachment attachment;

  @override
  ConsumerState<FilePreviewPage> createState() => _FilePreviewPageState();
}

class _FilePreviewPageState extends ConsumerState<FilePreviewPage> {
  String? _signedUrl;
  String? _localFilePath;
  bool _loading = true;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _sharing = false;
  final List<String> _tempFiles = [];

  // Swipe-to-dismiss state for image viewer.
  double _dragOffset = 0;
  final TransformationController _transformationController =
      TransformationController();
  static const _dismissThreshold = 150.0;

  bool get _isPdf => widget.attachment.type.toLowerCase() == 'application/pdf';

  bool get _isImage =>
      _imageMimeTypes.contains(widget.attachment.type.toLowerCase());

  bool get _isAtDefaultScale {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    return scale <= 1.05; // epsilon for float comparison
  }

  @override
  void initState() {
    super.initState();
    _loadAttachment();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _cleanupTempFiles();
    super.dispose();
  }

  void _cleanupTempFiles() {
    for (final path in _tempFiles) {
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {
        // Best-effort cleanup; ignore failures.
      }
    }
    _tempFiles.clear();
  }

  Future<void> _loadAttachment() async {
    final att = widget.attachment;
    final diagnostics = ref.read(diagnosticsCollectorProvider);

    // If no attachment id, try direct URL fallback.
    if (att.id == null || att.id!.isEmpty) {
      diagnostics.info(
        'attachment-preview',
        'source=signedUrl, attachmentId=missing, '
            'mimeType=${att.type}, fallback=directUrl',
      );
      if (mounted) {
        setState(() {
          _signedUrl = att.url;
          _loading = false;
          if (att.url == null) _error = 'No download URL available.';
        });
      }
      return;
    }

    try {
      final repo = ref.read(attachmentRepositoryProvider);
      final serverId = _extractServerId();
      final url = await repo.getSignedUrl(
        serverId,
        attachmentId: att.id!,
      );

      if (!mounted) return;
      setState(() => _signedUrl = url);

      if (_isPdf) {
        await _downloadPdf(url);
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } on AppFailure catch (e) {
      diagnostics.error(
        'attachment-preview',
        'source=signedUrl, attachmentId=${att.id}, '
            'mimeType=${att.type}, failureType=${e.runtimeType}',
      );
      // Fall back to direct URL if available (preserves old behavior).
      if (mounted) {
        if (att.url != null) {
          setState(() => _signedUrl = att.url);
          if (_isPdf) {
            // Keep _loading true so the spinner stays visible while
            // the fallback PDF download completes.
            await _downloadPdf(att.url!);
          } else {
            setState(() => _loading = false);
          }
        } else {
          setState(() {
            _error = 'Failed to load attachment.';
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        if (att.url != null) {
          setState(() => _signedUrl = att.url);
          if (_isPdf) {
            await _downloadPdf(att.url!);
          } else {
            setState(() => _loading = false);
          }
        } else {
          setState(() {
            _error = 'Failed to load attachment.';
            _loading = false;
          });
        }
      }
    }
  }

  Future<void> _downloadPdf(String url) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.attachment.name.isNotEmpty
          ? widget.attachment.name
          : 'preview.pdf';
      final filePath = '${tempDir.path}/$fileName';
      await Dio().download(url, filePath);
      _tempFiles.add(filePath);
      if (mounted) {
        setState(() {
          _localFilePath = filePath;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to download PDF.';
          _loading = false;
        });
      }
    }
  }

  ServerScopeId _extractServerId() {
    final target = ref.read(currentOpenConversationTargetProvider);
    if (target != null) return target.serverId;
    return const ServerScopeId('');
  }

  Future<void> _shareFile() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final url = _signedUrl;
      if (url == null) {
        if (mounted) setState(() => _sharing = false);
        return;
      }

      // For PDFs already downloaded, share from local path.
      if (_isPdf && _localFilePath != null) {
        await Share.shareXFiles([XFile(_localFilePath!)]);
        if (mounted) setState(() => _sharing = false);
        return;
      }

      // For other file types, download to temp first.
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.attachment.name.isNotEmpty
          ? widget.attachment.name
          : 'attachment';
      final filePath = '${tempDir.path}/$fileName';
      await Dio().download(url, filePath);
      _tempFiles.add(filePath);
      await Share.shareXFiles([XFile(filePath)]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Failed to share file.')),
          );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _openExternal() {
    final url = _signedUrl ?? widget.attachment.url;
    if (url != null) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      key: const ValueKey('file-preview-page'),
      backgroundColor: _isImage ? Colors.black : colors.surface,
      appBar: AppBar(
        key: const ValueKey('file-preview-toolbar'),
        backgroundColor: _isImage ? Colors.black : null,
        foregroundColor: _isImage ? Colors.white : null,
        title: Text(
          widget.attachment.name,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_signedUrl != null)
            IconButton(
              key: const ValueKey('file-preview-share'),
              icon: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
              onPressed: _sharing ? null : _shareFile,
              tooltip: 'Share',
            ),
          IconButton(
            key: const ValueKey('file-preview-open-external'),
            icon: const Icon(Icons.open_in_new),
            onPressed: _openExternal,
            tooltip: 'Open in external app',
          ),
        ],
      ),
      body: _buildBody(context, colors),
    );
  }

  Widget _buildBody(BuildContext context, AppColors colors) {
    if (_loading) {
      return Center(
        key: const ValueKey('file-preview-loading'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: _isImage ? Colors.white70 : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _isPdf ? 'Downloading PDF…' : 'Loading…',
              style: AppTypography.body.copyWith(
                color: _isImage ? Colors.white54 : colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        key: const ValueKey('file-preview-error'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: _isImage ? Colors.white54 : colors.textSecondary,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: AppTypography.body.copyWith(
                color: _isImage ? Colors.white54 : colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey('file-preview-retry'),
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadAttachment();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_isPdf) return _buildPdfBody(colors);
    if (_isImage) return _buildImageBody(colors);
    return _buildGenericBody(colors);
  }

  Widget _buildPdfBody(AppColors colors) {
    if (_localFilePath == null) {
      return Center(
        key: const ValueKey('file-preview-error'),
        child: Text(
          'PDF file not available.',
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return Stack(
      children: [
        PDFView(
          key: const ValueKey('pdf-viewer'),
          filePath: _localFilePath!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          onRender: (pages) {
            if (mounted && pages != null) {
              setState(() => _totalPages = pages);
            }
          },
          onPageChanged: (page, total) {
            if (mounted && page != null) {
              setState(() => _currentPage = page);
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() => _error = 'Failed to render PDF.');
            }
          },
        ),
        if (_totalPages > 1)
          Positioned(
            bottom: AppSpacing.lg,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                key: const ValueKey('pdf-page-indicator'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: AppTypography.label.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageBody(AppColors colors) {
    final displayUrl = _signedUrl ?? widget.attachment.url;
    if (displayUrl == null) {
      return Center(
        key: const ValueKey('file-preview-error'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Unable to load image.',
              style: AppTypography.body.copyWith(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      key: const ValueKey('media-viewer-dismiss-area'),
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (details) {
        if (!_isAtDefaultScale) return;
        setState(() => _dragOffset += details.delta.dy);
      },
      onVerticalDragEnd: (details) {
        if (_dragOffset > _dismissThreshold) {
          Navigator.of(context).pop();
        } else {
          setState(() => _dragOffset = 0);
        }
      },
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: Opacity(
          opacity: (1 - (_dragOffset.abs() / 500)).clamp(0.3, 1.0),
          child: Center(
            child: InteractiveViewer(
              key: const ValueKey('image-viewer-interactive'),
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                displayUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Unable to load image.',
                        style:
                            AppTypography.body.copyWith(color: Colors.white54),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenericBody(AppColors colors) {
    final att = widget.attachment;
    return Center(
      key: const ValueKey('generic-file-preview'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _fileTypeIcon(att.type),
              size: 64,
              color: colors.primary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              att.name,
              style: AppTypography.title.copyWith(color: colors.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              att.type,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            if (att.formattedSize != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                att.formattedSize!,
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              key: const ValueKey('generic-file-open'),
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open with…'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _fileTypeIcon(String mimeType) {
    final lower = mimeType.toLowerCase();
    if (lower.startsWith('text/')) return Icons.description_outlined;
    if (lower.startsWith('audio/')) return Icons.audio_file_outlined;
    if (lower.startsWith('video/')) return Icons.video_file_outlined;
    if (lower.contains('spreadsheet') || lower.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    if (lower.contains('presentation') || lower.contains('powerpoint')) {
      return Icons.slideshow_outlined;
    }
    if (lower.contains('zip') ||
        lower.contains('tar') ||
        lower.contains('compressed')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}
