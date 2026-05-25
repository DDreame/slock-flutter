import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/core/hero/hero_tags.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/application/download_priority_scheduler.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/csv_preview_widget.dart';
import 'package:slock_app/features/conversation/presentation/widgets/svg_preview_widget.dart';
import 'package:slock_app/features/conversation/presentation/widgets/text_preview_widget.dart';
import 'package:slock_app/features/voice/data/audio_player_service.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/presentation/widgets/voice_message_bubble.dart';

class AttachmentSection extends ConsumerWidget {
  const AttachmentSection({super.key, required this.attachments});

  final List<MessageAttachment> attachments;

  static const _imageTypes = {
    'image/png',
    'image/jpeg',
    'image/jpg',
    'image/gif',
    'image/webp',
  };

  static const _htmlTypes = {
    'text/html',
  };

  static const _csvTypes = {
    'text/csv',
    'application/csv',
  };

  static const _svgTypes = {
    'image/svg+xml',
  };

  static const _markdownTypes = {
    'text/markdown',
    'text/x-markdown',
  };

  static const _textTypes = {
    'text/plain',
  };

  /// Size limit for inline previews (1 MB). Larger files fall back to the
  /// generic attachment row (INV-ATTACH-3).
  static const _inlinePreviewSizeLimit = 1048576;

  static bool _isAudioType(String mimeType) => mimeType.startsWith('audio/');

  static bool _isMarkdownByExtension(String name) =>
      name.endsWith('.md') || name.endsWith('.markdown');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        key: const ValueKey('message-attachments'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final attachment in attachments)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildAttachmentWidget(context, ref, attachment),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentWidget(
    BuildContext context,
    WidgetRef ref,
    MessageAttachment attachment,
  ) {
    final mimeType = attachment.type.toLowerCase();

    if (_imageTypes.contains(mimeType) &&
        (attachment.thumbnailUrl != null || attachment.url != null)) {
      final imageWidget = _ImageAttachmentPreview(attachment: attachment);
      // Wrap in VisibilityDetector so the scheduler knows which items are
      // on-screen (priority) vs offscreen (deferred). The actual enqueue
      // happens eagerly in _registerAttachmentDownloads on message load.
      if (attachment.id != null) {
        return VisibilityDetector(
          key: Key('download-visibility-${attachment.id}'),
          onVisibilityChanged: (info) {
            // Guard: VisibilityDetector fires callbacks asynchronously (next
            // frame). If the widget tree was disposed between frames, ref is
            // invalid — ignore the late callback safely.
            try {
              ref.read(downloadSchedulerProvider.notifier).onVisibilityChanged(
                    attachment.id!,
                    info.visibleFraction > 0,
                  );
            } on StateError {
              // Widget disposed — ignore late visibility callback.
            }
          },
          child: imageWidget,
        );
      }
      return imageWidget;
    }

    if (_htmlTypes.contains(mimeType)) {
      return _HtmlAttachmentRow(attachment: attachment);
    }

    if (_isAudioType(mimeType) && attachment.url != null) {
      return _AudioAttachmentRow(attachment: attachment);
    }

    // Size gate (INV-ATTACH-3): skip inline preview for large files.
    if (attachment.sizeBytes != null &&
        attachment.sizeBytes! > _inlinePreviewSizeLimit) {
      return _GenericFileAttachmentRow(attachment: attachment);
    }

    final genericFallback = _GenericFileAttachmentRow(attachment: attachment);

    if (_csvTypes.contains(mimeType)) {
      return CsvPreviewWidget(
        attachment: attachment,
        fallback: genericFallback,
      );
    }

    if (_svgTypes.contains(mimeType)) {
      return SvgPreviewWidget(
        attachment: attachment,
        fallback: genericFallback,
      );
    }

    if (_markdownTypes.contains(mimeType) ||
        _isMarkdownByExtension(attachment.name)) {
      return TextPreviewWidget(
        attachment: attachment,
        isMarkdown: true,
        fallback: genericFallback,
      );
    }

    if (_textTypes.contains(mimeType)) {
      return TextPreviewWidget(
        attachment: attachment,
        isMarkdown: false,
        fallback: genericFallback,
      );
    }

    return _GenericFileAttachmentRow(attachment: attachment);
  }
}

class _ImageAttachmentPreview extends StatelessWidget {
  const _ImageAttachmentPreview({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: attachment.name.isNotEmpty ? attachment.name : 'Image attachment',
      onTap: () => _openFullScreen(context),
      child: GestureDetector(
        key: ValueKey('image-preview-${attachment.id ?? attachment.name}'),
        onTap: () => _openFullScreen(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 200,
                  maxWidth: 280,
                ),
                child: Hero(
                  tag: HeroTags.imageAttachment(
                      attachment.id ?? attachment.name),
                  child: CachedNetworkImage(
                    imageUrl: attachment.thumbnailUrl ?? attachment.url!,
                    memCacheWidth: 280,
                    fit: BoxFit.cover,
                    progressIndicatorBuilder: (context, url, progress) {
                      return SizedBox(
                        height: 120,
                        width: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: progress.progress,
                          ),
                        ),
                      );
                    },
                    errorWidget: (context, url, error) {
                      return Container(
                        height: 80,
                        width: 200,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              attachment.name,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              attachment.name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    // Use GoRouter push instead of Navigator.push so the page
    // is visible to GoRouter's navigation stack.
    context.push('/file-preview', extra: attachment);
  }
}

class _FullScreenImageViewer extends ConsumerStatefulWidget {
  const _FullScreenImageViewer({required this.attachment});

  final MessageAttachment attachment;

  @override
  ConsumerState<_FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

class _FullScreenImageViewerState
    extends ConsumerState<_FullScreenImageViewer> {
  String? _signedUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  Future<void> _loadSignedUrl() async {
    final att = widget.attachment;
    final diagnostics = ref.read(diagnosticsCollectorProvider);
    // If no id, fall back to direct url (legacy attachment).
    if (att.id == null || att.id!.isEmpty) {
      diagnostics.info(
        'attachment-preview',
        'source=signedUrl, attachmentId=missing, '
            'mimeType=${att.type}, fallback=directUrl',
      );
      setState(() => _signedUrl = att.url);
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(attachmentRepositoryProvider);
      final serverId = _extractServerIdFromContext();
      final url = await repo.getSignedUrl(
        serverId,
        attachmentId: att.id!,
      );
      if (mounted) {
        setState(() {
          _signedUrl = url;
          _loading = false;
        });
      }
    } on AppFailure catch (e) {
      diagnostics.error(
        'attachment-preview',
        'source=signedUrl, attachmentId=${att.id}, '
            'mimeType=${att.type}, failureType=${e.runtimeType}',
      );
      if (mounted) {
        setState(() {
          _signedUrl = att.url;
          _loading = false;
        });
      }
    }
  }

  ServerScopeId _extractServerIdFromContext() {
    // Best-effort extraction from open conversation target.
    final target = ref.read(currentOpenConversationTargetProvider);
    if (target != null) return target.serverId;
    // Fallback: use a default — signed URLs require server scope.
    return const ServerScopeId('');
  }

  @override
  Widget build(BuildContext context) {
    final displayUrl = _signedUrl ?? widget.attachment.url;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.attachment.name,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          if (displayUrl != null)
            IconButton(
              key: const ValueKey('image-viewer-open-external'),
              icon: const Icon(Icons.open_in_new),
              onPressed: () => launchUrl(
                Uri.parse(displayUrl),
                mode: LaunchMode.externalApplication,
              ),
              tooltip: context.l10n.attachmentOpenInBrowser,
            ),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white70)
            : displayUrl != null
                ? InteractiveViewer(
                    key: const ValueKey('image-viewer-interactive'),
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: displayUrl,
                      fit: BoxFit.contain,
                      errorWidget: (context, url, error) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.attachmentUnableToLoadImage,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.white54),
                            ),
                          ],
                        );
                      },
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.attachmentUnableToLoadImage,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _HtmlAttachmentRow extends ConsumerWidget {
  const _HtmlAttachmentRow({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('html-attachment-${attachment.id ?? attachment.name}'),
      onTap: () => _openHtmlPreview(context, ref),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [
                      context.l10n.attachmentHtmlOpensInBrowser,
                      if (attachment.formattedSize != null)
                        attachment.formattedSize!,
                    ].join(' · '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.open_in_new,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openHtmlPreview(BuildContext context, WidgetRef ref) async {
    final diagnostics = ref.read(diagnosticsCollectorProvider);
    // If we have an attachment id, use the html-preview-url endpoint.
    if (attachment.id != null && attachment.id!.isNotEmpty) {
      try {
        final target = ref.read(currentOpenConversationTargetProvider);
        if (target == null) return;
        final repo = ref.read(attachmentRepositoryProvider);
        final previewUrl = await repo.getHtmlPreviewUrl(
          target.serverId,
          attachmentId: attachment.id!,
        );
        await launchUrl(
          Uri.parse(previewUrl),
          mode: LaunchMode.externalApplication,
        );
        return;
      } on AppFailure catch (e) {
        diagnostics.error(
          'attachment-preview',
          'source=htmlPreview, attachmentId=${attachment.id}, '
              'mimeType=${attachment.type}, failureType=${e.runtimeType}',
        );
        // Fall through to direct URL if available.
      }
    } else {
      diagnostics.info(
        'attachment-preview',
        'source=htmlPreview, attachmentId=missing, '
            'mimeType=${attachment.type}, fallback=directUrl',
      );
    }
    // Fallback: use direct url if present.
    if (attachment.url != null) {
      await launchUrl(
        Uri.parse(attachment.url!),
        mode: LaunchMode.externalApplication,
      );
    }
  }
}

class _GenericFileAttachmentRow extends ConsumerWidget {
  const _GenericFileAttachmentRow({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasTapTarget = attachment.url != null || attachment.id != null;
    return InkWell(
      key: ValueKey('file-attachment-${attachment.id ?? attachment.name}'),
      onTap: hasTapTarget ? () => _openFile(context, ref) : null,
      borderRadius: BorderRadius.circular(4),
      child: Row(
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasTapTarget ? theme.colorScheme.primary : null,
                decoration: hasTapTarget ? TextDecoration.underline : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            [
              attachment.type,
              if (attachment.formattedSize != null) attachment.formattedSize!,
            ].join(' · '),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(BuildContext context, WidgetRef ref) async {
    // Use GoRouter push instead of Navigator.push so the page
    // is visible to GoRouter's navigation stack.
    context.push('/file-preview', extra: attachment);
  }
}

/// Inline audio player for voice/audio attachments in chat messages.
class _AudioAttachmentRow extends ConsumerStatefulWidget {
  const _AudioAttachmentRow({required this.attachment});

  final MessageAttachment attachment;

  @override
  ConsumerState<_AudioAttachmentRow> createState() =>
      _AudioAttachmentRowState();
}

class _AudioAttachmentRowState extends ConsumerState<_AudioAttachmentRow> {
  late final AudioAttachmentPlayerPool _playerPool;
  late final AudioPlayerController _player;
  late final String _audioKey;
  AudioPlaybackState _playbackState = AudioPlaybackState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<AudioPlaybackState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  bool _initialized = false;
  List<double> _waveform = const [];
  bool _hasPlaybackError = false;

  @override
  void initState() {
    super.initState();
    _playerPool = ref.read(audioAttachmentPlayerPoolProvider.notifier);
    _player = _playerPool.player;
    _audioKey = widget.attachment.url ?? widget.attachment.name;
    _resolveWaveform();
  }

  /// Resolve waveform data: use cached amplitudes for own recordings,
  /// or load audio eagerly to derive duration-based waveform for received audio.
  void _resolveWaveform() {
    // Check cache for own recordings (real amplitudes from recording session).
    final cached = ref
        .read(voiceWaveformCacheProvider.notifier)
        .get(widget.attachment.name);
    if (cached != null && cached.isNotEmpty) {
      _waveform = cached;
      return;
    }
    // For received audio, load the audio to get its duration.
    _loadAudioForWaveform();
  }

  Future<void> _loadAudioForWaveform() async {
    final url = widget.attachment.url;
    if (url == null) return;
    try {
      _ensureSubscriptions();
      final duration = await _playerPool.load(_audioKey, url);
      if (duration != null && mounted) {
        setState(() {
          _duration = duration;
          _waveform = _waveformFromDuration(duration);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hasPlaybackError = true);
    }
  }

  /// Generate a duration-proportional waveform approximation.
  ///
  /// Produces ~1 bar per 0.75s of audio (capped at 50 bars, minimum 8).
  /// Bar heights vary in a smooth sine-based pattern to give a natural
  /// audio-like appearance while being deterministic per duration.
  static List<double> _waveformFromDuration(Duration duration) {
    final seconds = duration.inMilliseconds / 1000.0;
    final barCount = (seconds / 0.75).round().clamp(8, 50);
    return List.generate(barCount, (i) {
      // Smooth varying pattern based on index position.
      final t = i / barCount;
      final base = 0.3 + 0.4 * math.sin(t * math.pi * 3.7);
      final detail = 0.15 * math.sin(t * math.pi * 11.3 + 0.7);
      return (base + detail).clamp(0.15, 0.95);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  void _ensureSubscriptions() {
    if (_initialized) return;
    _initialized = true;
    _stateSub = _player.stateStream.listen((s) {
      if (!mounted) return;
      if (!_playerPool.isActive(_audioKey)) {
        setState(() {
          _playbackState = AudioPlaybackState.stopped;
        });
        return;
      }
      setState(() {
        _playbackState = s;
        if (s != AudioPlaybackState.error) {
          _hasPlaybackError = false;
        }
      });
      if (s == AudioPlaybackState.error) {
        _showPlaybackError();
      }
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        _playbackState = AudioPlaybackState.error;
        _hasPlaybackError = true;
      });
      _showPlaybackError();
    });
    _positionSub = _player.positionStream.listen((p) {
      if (mounted && _playerPool.isActive(_audioKey)) {
        setState(() => _position = p);
      }
    });
    _durationSub = _player.durationStream.listen((d) {
      if (mounted && _playerPool.isActive(_audioKey)) {
        setState(() => _duration = d);
      }
    });
  }

  Future<void> _handlePlayPause() async {
    _ensureSubscriptions();
    final url = widget.attachment.url;
    if (url == null) return;
    switch (_playbackState) {
      case AudioPlaybackState.stopped:
      case AudioPlaybackState.error:
        await _playerPool.play(_audioKey, url);
        _syncPlaybackResult();
      case AudioPlaybackState.playing:
        await _playerPool.pause(_audioKey);
        _syncPlaybackResult();
      case AudioPlaybackState.paused:
        await _playerPool.resume(_audioKey);
        _syncPlaybackResult();
    }
  }

  Future<void> _handleSeek(double fraction) async {
    if (_duration.inMilliseconds <= 0) return;
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * fraction).round(),
    );
    await _playerPool.seek(_audioKey, target);
    _syncPlaybackResult();
  }

  void _syncPlaybackResult() {
    final state = _player.state;
    if (!mounted) return;
    setState(() {
      _playbackState = state;
      _hasPlaybackError = state == AudioPlaybackState.error;
    });
    if (state != AudioPlaybackState.playing &&
        state != AudioPlaybackState.paused) {
      _playerPool.clearIfActive(_audioKey);
    }
    if (state == AudioPlaybackState.error) {
      _showPlaybackError();
    }
  }

  void _showPlaybackError() {
    if (!mounted) return;
    setState(() => _hasPlaybackError = true);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.audioPlaybackFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(audioAttachmentPlayerPoolProvider);
    return SizedBox(
      width: 240,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          VoiceMessageBubble(
            duration: _duration,
            position: _position,
            isPlaying: _playbackState == AudioPlaybackState.playing,
            waveform: _waveform,
            onPlayPause: _handlePlayPause,
            onSeek: _handleSeek,
          ),
          if (_hasPlaybackError)
            Icon(
              Icons.error_outline,
              key: const ValueKey('audio-playback-error'),
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
        ],
      ),
    );
  }
}
