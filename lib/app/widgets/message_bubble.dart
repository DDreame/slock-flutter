import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';

/// Visual variant of a [MessageBubble].
enum MessageBubbleVariant {
  /// Current user's message — right-aligned, primary fill, white text.
  self,

  /// Another human's message — left-aligned, surfaceAlt fill, name label.
  other,

  /// Agent's message — left-aligned, agentLight fill, "AI" label.
  agent,

  /// System notification — centered, italic, no bubble.
  system,
}

/// A chat message bubble styled per the Z3 design system.
///
/// Uses asymmetric border radii: 18px on all corners except 6px on the
/// sender's origin side (top-right for self, top-left for other/agent).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.variant,
    this.senderName,
    required this.child,
  });

  /// Determines layout, alignment, and fill color.
  final MessageBubbleVariant variant;

  /// Sender display name (shown for [other] and [agent] variants).
  final String? senderName;

  /// The message content widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final alignment = switch (variant) {
      MessageBubbleVariant.self => Alignment.centerRight,
      MessageBubbleVariant.system => Alignment.center,
      _ => Alignment.centerLeft,
    };

    final bubbleColor = switch (variant) {
      MessageBubbleVariant.self => colors.primary,
      MessageBubbleVariant.other => colors.surfaceAlt,
      MessageBubbleVariant.agent => colors.agentLight,
      MessageBubbleVariant.system => null,
    };

    final textColor = switch (variant) {
      MessageBubbleVariant.self => colors.primaryForeground,
      MessageBubbleVariant.system => colors.textSecondary,
      _ => colors.text,
    };

    final fontStyle = variant == MessageBubbleVariant.system
        ? FontStyle.italic
        : FontStyle.normal;

    final borderRadius = switch (variant) {
      MessageBubbleVariant.self => const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      MessageBubbleVariant.system => BorderRadius.circular(18),
      _ => const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
    };

    final showSenderLabel = variant == MessageBubbleVariant.other ||
        variant == MessageBubbleVariant.agent;

    Widget content = Container(
      key: const ValueKey('message-bubble-container'),
      padding: variant == MessageBubbleVariant.system
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            )
          : const EdgeInsets.all(AppSpacing.md),
      decoration: bubbleColor != null
          ? BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
            )
          : const BoxDecoration(),
      child: DefaultTextStyle(
        style: AppTypography.body.copyWith(
          color: textColor,
          fontStyle: fontStyle,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSenderLabel)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (variant == MessageBubbleVariant.agent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.agentAccent,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Text(
                          'AI',
                          style: AppTypography.caption.copyWith(
                            color: colors.primaryForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Text(
                      senderName ?? '',
                      style: AppTypography.label.copyWith(
                        color: variant == MessageBubbleVariant.agent
                            ? colors.agentAccent
                            : colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );

    if (variant != MessageBubbleVariant.system) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: content,
      );
    }

    return Align(
      key: const ValueKey('message-bubble-shell'),
      alignment: alignment,
      child: content,
    );
  }
}
