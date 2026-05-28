import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/link_preview/data/link_metadata.dart';
import 'package:slock_app/l10n/l10n.dart';

/// A card widget that displays a rich URL preview with image,
/// title, description, and domain.
class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({
    super.key,
    required this.metadata,
    this.onTap,
  });

  /// Hoisted border radius to avoid per-build allocations.
  static final borderRadius = BorderRadius.circular(12);

  /// The link metadata to display.
  final LinkMetadata metadata;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    return Semantics(
      link: true,
      label: l10n.linkPreviewSemantics(metadata.domain),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: const ValueKey('link-preview-card'),
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            borderRadius: borderRadius,
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (metadata.imageUrl != null) _buildImage(colors),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Domain chip
                    Text(
                      metadata.domain,
                      key: const ValueKey('link-preview-domain'),
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Title
                    Text(
                      metadata.title,
                      key: const ValueKey('link-preview-title'),
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (metadata.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        metadata.description!,
                        key: const ValueKey('link-preview-description'),
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(AppColors colors) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 160),
      child: CachedNetworkImage(
        imageUrl: metadata.imageUrl!,
        key: const ValueKey('link-preview-image'),
        memCacheHeight: 160,
        fit: BoxFit.cover,
        width: double.infinity,
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
