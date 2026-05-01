import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';

// -- Layout constants --
const double _kH3FontSize = 14.0;
const double _kCodeFontSizeScale = 0.9;
const double _kCodeFontSizeFallback = 12.6;
const double _kBlockquoteBorderWidth = 3.0;
const double _kHorizontalRuleWidth = 1.0;
const double _kCodeBlockMaxHeight = 200.0;
const double _kSelfOverlayAlpha = 0.15;
const double _kSelfSecondaryAlpha = 0.78;
const double _kSelfBlockquoteAlpha = 0.5;

/// Custom code-block builder that constrains height and enables vertical
/// scrolling for long fenced code blocks (Z2 spec: max 200 dp).
///
/// The outer `Container(decoration: codeblockDecoration)` is applied by
/// flutter_markdown unconditionally for `<pre>` tags, so this builder only
/// needs to produce the inner scrollable content.
class _ScrollableCodeBlockBuilder extends MarkdownElementBuilder {
  _ScrollableCodeBlockBuilder({
    required this.maxHeight,
    required this.codeStyle,
    required this.padding,
  });

  final double maxHeight;
  final TextStyle codeStyle;
  final EdgeInsets padding;

  // Accumulate code text across visitText calls.
  String _buffer = '';

  @override
  void visitElementBefore(md.Element element) {
    _buffer = '';
  }

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    // Accumulate text; the full widget is built in visitElementAfterWithContext.
    _buffer += text.text;
    // Return a placeholder so the inline stack stays balanced.
    return const SizedBox.shrink();
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = _buffer.isNotEmpty ? _buffer : element.textContent;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: padding,
            child: Text(code, style: preferredStyle ?? codeStyle),
          ),
        ),
      ),
    );
  }
}

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
/// - **Self bubble**: code uses white overlay bg, links use white + underline
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
      key: const ValueKey('markdown-body'),
      data: content,
      styleSheet: styleSheet,
      onTapLink: onLinkTap,
      selectable: true,
      builders: {
        'pre': _ScrollableCodeBlockBuilder(
          maxHeight: _kCodeBlockMaxHeight,
          codeStyle: styleSheet.code!,
          padding: styleSheet.codeblockPadding!,
        ),
      },
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
        ? colors.primaryForeground.withValues(alpha: _kSelfSecondaryAlpha)
        : colors.textSecondary;

    // Inline code colors
    final codeBackground = isSelf
        ? Colors.white.withValues(alpha: _kSelfOverlayAlpha)
        : colors.surfaceAlt;
    final codeTextColor = isSelf ? colors.primaryForeground : colors.primary;

    // Code block colors
    final codeBlockBackground = isSelf
        ? Colors.white.withValues(alpha: _kSelfOverlayAlpha)
        : colors.surfaceAlt;

    // Link colors
    final linkColor = isSelf ? colors.primaryForeground : colors.primary;
    final linkDecoration =
        isSelf ? TextDecoration.underline : TextDecoration.none;

    // Blockquote
    final blockquoteBorderColor = isSelf
        ? colors.primaryForeground.withValues(alpha: _kSelfBlockquoteAlpha)
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
        fontSize: _kH3FontSize,
        fontWeight: FontWeight.w600,
      ),
      h3Padding: const EdgeInsets.only(bottom: AppSpacing.xs),

      // --- Inline code ---
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: effectiveBase.fontSize != null
            ? effectiveBase.fontSize! * _kCodeFontSizeScale
            : _kCodeFontSizeFallback,
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
            width: _kBlockquoteBorderWidth,
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
          top: BorderSide(
            color: colors.border,
            width: _kHorizontalRuleWidth,
          ),
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
