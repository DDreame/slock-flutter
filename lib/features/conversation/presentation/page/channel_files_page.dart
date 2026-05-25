import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/channel_files_repository.dart';
import 'package:slock_app/features/conversation/data/channel_files_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Page that lists all files shared in a channel, sorted newest-first
/// (INV-FILES-1). Tapping a file opens FilePreviewPage (INV-FILES-2).
/// Shows an empty state when no files exist (INV-FILES-3).
class ChannelFilesPage extends ConsumerStatefulWidget {
  final String serverId;
  final String channelId;

  /// Optional override for the repository, used in tests.
  final ChannelFilesRepository? repositoryOverride;

  const ChannelFilesPage({
    super.key,
    required this.serverId,
    required this.channelId,
    this.repositoryOverride,
  });

  @override
  ConsumerState<ChannelFilesPage> createState() => _ChannelFilesPageState();
}

class _ChannelFilesPageState extends ConsumerState<ChannelFilesPage> {
  List<MessageAttachment>? _files;
  bool _loading = true;
  String? _error;

  /// Sort newest-first by [createdAt]. Files without a timestamp sort last,
  /// preserving their original relative order (INV-FILES-1).
  static int _newestFirst(MessageAttachment a, MessageAttachment b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadFiles);
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ChannelFilesRepository repo =
          widget.repositoryOverride ?? ref.read(channelFilesRepositoryProvider);
      final files = await repo.listFiles(
        ServerScopeId(widget.serverId),
        channelId: widget.channelId,
      );
      if (!mounted) return;
      setState(() {
        _files = files;
        _loading = false;
      });
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.userMessage(context.l10n);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.errorUnknown;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('channel-files-page'),
      appBar: AppBar(
        title: Text(context.l10n.conversationFilesTitle),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        key: ValueKey('channel-files-loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        key: const ValueKey('channel-files-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const ValueKey('channel-files-retry'),
              onPressed: _loadFiles,
              child: Text(context.l10n.conversationFilesRetry),
            ),
          ],
        ),
      );
    }

    final files = List<MessageAttachment>.of(_files ?? [])..sort(_newestFirst);
    if (files.isEmpty) {
      final colors = Theme.of(context).extension<AppColors>()!;
      return Center(
        key: const ValueKey('channel-files-empty'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_outlined,
                  size: 48, color: colors.textTertiary),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.conversationFilesEmpty,
                style: AppTypography.body.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey('channel-files-list'),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return _FileListTile(
          key: ValueKey('channel-file-${file.name}-$index'),
          attachment: file,
          onTap: () => context.push('/file-preview', extra: file),
        );
      },
    );
  }
}

class _FileListTile extends StatelessWidget {
  const _FileListTile({
    super.key,
    required this.attachment,
    required this.onTap,
  });

  final MessageAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        _iconForMimeType(attachment.type),
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        attachment.name,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: attachment.formattedSize != null
          ? Text(
              attachment.formattedSize!,
              style: theme.textTheme.bodySmall,
            )
          : null,
      onTap: onTap,
    );
  }

  static IconData _iconForMimeType(String type) {
    if (type.startsWith('image/')) return Icons.image_outlined;
    if (type.startsWith('video/')) return Icons.videocam_outlined;
    if (type.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (type == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (type == 'text/csv' || type == 'application/csv') {
      return Icons.table_chart_outlined;
    }
    if (type.startsWith('text/')) return Icons.description_outlined;
    return Icons.attach_file;
  }
}
