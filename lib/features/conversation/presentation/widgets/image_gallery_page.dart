import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/core/hero/hero_tags.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart'
    show attachmentRepositoryProvider;
import 'package:slock_app/features/conversation/data/conversation_repository.dart'
    show MessageAttachment;
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';

/// Arguments passed via GoRouter extra for the image gallery route.
class ImageGalleryArgs {
  const ImageGalleryArgs({
    required this.images,
    required this.initialIndex,
  });

  /// All image attachments from the message.
  final List<MessageAttachment> images;

  /// Index of the initially-visible image (the one tapped).
  final int initialIndex;
}

/// Full-screen multi-image gallery with PageView swiping, pinch-to-zoom,
/// index indicator (1/N), and swipe-to-dismiss.
class ImageGalleryPage extends ConsumerStatefulWidget {
  const ImageGalleryPage({super.key, required this.args});

  final ImageGalleryArgs args;

  /// Hoisted BorderRadius for the index indicator pill.
  @visibleForTesting
  static final indicatorBorderRadius = BorderRadius.circular(AppSpacing.md);

  /// Hoisted TextStyle for the index indicator text.
  @visibleForTesting
  static final indicatorTextStyle =
      AppTypography.label.copyWith(color: Colors.white);

  /// Hoisted TextStyle for error/fallback text.
  @visibleForTesting
  static final errorTextStyle =
      AppTypography.body.copyWith(color: Colors.white54);

  @override
  ConsumerState<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends ConsumerState<ImageGalleryPage> {
  late final PageController _pageController;
  late int _currentIndex;

  /// Per-page signed URL cache (resolved lazily).
  final Map<int, String?> _signedUrls = {};

  /// Per-page loading state.
  final Map<int, bool> _loadingStates = {};

  // Swipe-to-dismiss state.
  double _dragOffset = 0;
  static const _dismissThreshold = 150.0;

  /// Per-page TransformationController to track zoom state.
  final Map<int, TransformationController> _transformControllers = {};

  bool get _isAtDefaultScale {
    final controller = _transformControllers[_currentIndex];
    if (controller == null) return true;
    return controller.value.getMaxScaleOnAxis() <= 1.05;
  }

  @override
  void initState() {
    super.initState();
    // Clamp to valid range to prevent index-out-of-range crash.
    _currentIndex =
        widget.args.initialIndex.clamp(0, widget.args.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    // Kick off URL resolution for the initial page.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _resolveUrl(_currentIndex));
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _transformControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _getTransformController(int index) {
    return _transformControllers.putIfAbsent(
      index,
      () => TransformationController(),
    );
  }

  Future<void> _resolveUrl(int index) async {
    if (_signedUrls.containsKey(index)) return;

    final attachment = widget.args.images[index];
    final diagnostics = ref.read(diagnosticsCollectorProvider);

    // If no id, use direct URL immediately.
    if (attachment.id == null || attachment.id!.isEmpty) {
      diagnostics.info(
        'attachment-preview',
        'source=signedUrl, attachmentId=missing, '
            'mimeType=${attachment.type}, fallback=directUrl',
      );
      if (mounted) {
        setState(() {
          _signedUrls[index] = attachment.url;
          _loadingStates[index] = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _loadingStates[index] = true);

    try {
      final repo = ref.read(attachmentRepositoryProvider);
      final target = ref.read(currentOpenConversationTargetProvider);
      final serverId = target?.serverId ?? const ServerScopeId('');
      final url = await repo.getSignedUrl(
        serverId,
        attachmentId: attachment.id!,
      );
      if (mounted) {
        setState(() {
          _signedUrls[index] = url;
          _loadingStates[index] = false;
        });
      }
    } on AppFailure catch (e) {
      diagnostics.error(
        'attachment-preview',
        'source=signedUrl, attachmentId=${attachment.id}, '
            'mimeType=${attachment.type}, failureType=${e.runtimeType}',
      );
      // Fall back to direct URL.
      if (mounted) {
        setState(() {
          _signedUrls[index] = attachment.url;
          _loadingStates[index] = false;
        });
      }
    } catch (_) {
      // Fall back to direct URL.
      if (mounted) {
        setState(() {
          _signedUrls[index] = attachment.url;
          _loadingStates[index] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.args.images;
    final currentAttachment = images[_currentIndex];

    return Scaffold(
      key: const ValueKey('image-gallery-page'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        key: const ValueKey('image-gallery-toolbar'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          currentAttachment.name,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        children: [
          // Swipe-to-dismiss wrapper around the PageView.
          GestureDetector(
            key: const ValueKey('gallery-dismiss-area'),
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (details) {
              if (!_isAtDefaultScale) return;
              setState(() => _dragOffset += details.delta.dy);
            },
            onVerticalDragEnd: (details) {
              if (_dragOffset.abs() > _dismissThreshold) {
                Navigator.of(context).pop();
              } else {
                setState(() => _dragOffset = 0);
              }
            },
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Opacity(
                opacity: (1 - (_dragOffset.abs() / 500)).clamp(0.3, 1.0),
                child: PageView.builder(
                  key: const ValueKey('gallery-page-view'),
                  controller: _pageController,
                  itemCount: images.length,
                  // Disable PageView swiping while zoomed to avoid conflicts.
                  physics: _isAtDefaultScale
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                    _resolveUrl(index);
                  },
                  itemBuilder: (context, index) =>
                      _buildPage(context, index, images[index]),
                ),
              ),
            ),
          ),
          // Index indicator (1/N) — only show when multiple images.
          if (images.length > 1)
            Positioned(
              bottom: AppSpacing.lg,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  key: const ValueKey('gallery-index-indicator'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: ImageGalleryPage.indicatorBorderRadius,
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${images.length}',
                    style: ImageGalleryPage.indicatorTextStyle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(
      BuildContext context, int index, MessageAttachment attachment) {
    final isLoading = _loadingStates[index] ?? true;
    final url = _signedUrls[index];

    if (isLoading && url == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }

    final displayUrl = url ?? attachment.thumbnailUrl ?? attachment.url;
    if (displayUrl == null) {
      return Center(
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
              context.l10n.filePreviewImageLoadFailed,
              style: ImageGalleryPage.errorTextStyle,
            ),
          ],
        ),
      );
    }

    final transformController = _getTransformController(index);
    final isZoomed = transformController.value.getMaxScaleOnAxis() > 1.05;

    // Only apply Hero on the initial page to avoid conflicting animations.
    final isInitialPage = index == widget.args.initialIndex;
    final heroTag = HeroTags.imageAttachment(attachment.id ?? attachment.name);

    Widget imageWidget = InteractiveViewer(
      key: ValueKey('gallery-interactive-viewer-$index'),
      transformationController: transformController,
      minScale: 0.5,
      maxScale: 4.0,
      // Disable panning at default scale so PageView receives horizontal drags.
      // When zoomed, panning is needed to move around the zoomed image.
      panEnabled: isZoomed,
      onInteractionEnd: (_) {
        // Force rebuild to update zoom state checks.
        setState(() {});
      },
      child: Center(
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
                const SizedBox(height: AppSpacing.md),
                Text(
                  context.l10n.filePreviewImageLoadFailed,
                  style: ImageGalleryPage.errorTextStyle,
                ),
              ],
            );
          },
        ),
      ),
    );

    if (isInitialPage) {
      imageWidget = Hero(
        tag: heroTag,
        child: imageWidget,
      );
    }

    return Semantics(
      button: true,
      label: context.l10n.filePreviewDismissSemantics,
      child: imageWidget,
    );
  }
}
