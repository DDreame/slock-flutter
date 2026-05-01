import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';

/// Bubble kind for Markdown style token selection.
///
/// Mirrors the visual kind enum from the conversation detail page
/// but is a public API for the reusable widget.
enum MessageBubbleKind { self, other, agent }

/// Renders message content as Markdown using `flutter_markdown`.
///
/// Supported subset: bold, italic, strikethrough, inline code, code block,
/// ordered/unordered lists, blockquote, links, H1-H3.
///
/// Not supported: images (stripped), tables, inline HTML.
///
/// Style tokens follow the Z2 design spec with bubble-variant-aware colors:
/// - **Self bubble**: code uses `rgba(255,255,255,0.15)` bg, links use white + underline
/// - **Other/Agent bubble**: standard AppColors tokens
class MarkdownMessageBody extends StatelessWidget {
  const MarkdownMessageBody({
    super.key,
    required this.content,
    this.kind = MessageBubbleKind.other,
    this.baseStyle,
    this.onLinkTap,
  });

  /// The raw message content to render as Markdown.
  final String content;

  /// Which bubble variant this body is inside. Affects style tokens.
  final MessageBubbleKind kind;

  /// Optional base text style (overrides theme defaults).
  final TextStyle? baseStyle;

  /// Called when a user taps a link. If null, links are not interactive.
  final void Function(String text, String? href, String title)? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styleSheet = _buildStyleSheet(context, colors);

    return MarkdownBody(
      data: content,
      styleSheet: styleSheet,
      onTapLink: onLinkTap,
      // Only allow supported inline syntax + block elements.
      // Use ExtensionSet.gitHubFlavored for strikethrough support.
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [
          md.StrikethroughSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes
              .where((s) => s is! md.AutolinkExtensionSyntax),
        ],
      ),
      // Strip images — not supported in this scope
      sizedImageBuilder: (_) => const SizedBox.shrink(),
      shrinkWrap: true,
      softLineBreak: true,
    );
  }

  MarkdownStyleSheet _buildStyleSheet(
    BuildContext context,
    AppColors colors,
  ) {
    final isSelf = kind == MessageBubbleKind.self;
    final effectiveBase = baseStyle ?? AppTypography.body;

    // Text colors depend on bubble variant
    final textColor = isSelf ? colors.primaryForeground : colors.text;
    final secondaryColor = isSelf
        ? colors.primaryForeground.withValues(alpha: 0.78)
        : colors.textSecondary;

    // Inline code colors
    final codeBackground =
        isSelf ? Colors.white.withValues(alpha: 0.15) : colors.surfaceAlt;
    final codeTextColor = isSelf ? colors.primaryForeground : colors.primary;

    // Code block colors
    final codeBlockBackground =
        isSelf ? Colors.white.withValues(alpha: 0.15) : colors.surfaceAlt;

    // Link colors
    final linkColor = isSelf ? colors.primaryForeground : colors.primary;
    final linkDecoration =
        isSelf ? TextDecoration.underline : TextDecoration.none;

    // Blockquote
    final blockquoteBorderColor = isSelf
        ? colors.primaryForeground.withValues(alpha: 0.5)
        : colors.primary;
    final blockquoteColor = secondaryColor;

    return MarkdownStyleSheet(
      // --- Paragraph / base text ---
      p: effectiveBase.copyWith(color: textColor),
      pPadding: EdgeInsets.zero,

      // --- Headings ---
      h1: AppTypography.headline.copyWith(color: textColor),
      h1Padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      h2: AppTypography.title.copyWith(color: textColor),
      h2Padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      h3: AppTypography.title.copyWith(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      h3Padding: const EdgeInsets.only(bottom: AppSpacing.xs),

      // --- Inline code ---
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: effectiveBase.fontSize != null
            ? effectiveBase.fontSize! * 0.9
            : 12.6,
        color: codeTextColor,
        backgroundColor: codeBackground,
      ),
      codeblockPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBlockBackground,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),

      // --- Blockquote ---
      blockquote: effectiveBase.copyWith(
        color: blockquoteColor,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: blockquoteBorderColor,
            width: 3,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: AppSpacing.md),

      // --- Links ---
      a: effectiveBase.copyWith(
        color: linkColor,
        decoration: linkDecoration,
      ),

      // --- Lists ---
      listBullet: effectiveBase.copyWith(color: textColor),

      // --- Strikethrough (handled via inline code, no dedicated field) ---

      // --- Horizontal rule ---
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
      ),

      // --- Table (not supported but provide safe defaults) ---
      tableBorder: TableBorder.all(color: colors.border),
      tableHead: effectiveBase.copyWith(
        color: textColor,
        fontWeight: FontWeight.bold,
      ),
      tableBody: effectiveBase.copyWith(color: textColor),

      // --- General spacing ---
      blockSpacing: AppSpacing.sm,
    );
  }
}
