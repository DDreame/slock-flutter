import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/conversation/presentation/widgets/inline_ref_syntax.dart';
import 'package:slock_app/features/conversation/presentation/widgets/mention_syntax.dart';

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

/// Pre-computed inline syntaxes from GitHub Flavored Markdown without
/// AutolinkExtensionSyntax. Computed once — avoids repeated .where()
/// iteration on every message bubble rebuild.
final List<md.InlineSyntax> _kGfmInlineSyntaxesWithoutAutolink = md
    .ExtensionSet.gitHubFlavored.inlineSyntaxes
    .where((s) => s is! md.AutolinkExtensionSyntax)
    .toList(growable: false);

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
///
/// INV-MD-STYLE-CACHE-1: Converted to StatefulWidget to cache the
/// MarkdownStyleSheet and builders map. Rebuilt only when theme or
/// widget properties (kind, baseStyle) change — not on every parent rebuild.
class MarkdownMessageBody extends StatefulWidget {
  const MarkdownMessageBody({
    super.key,
    required this.content,
    this.kind = MessageBubbleKind.other,
    this.baseStyle,
    this.onLinkTap,
    this.currentUserName,
    this.onMentionTap,
    this.onChannelRefTap,
    this.onTaskRefTap,
    this.onThreadRefTap,
  });

  /// The raw message content to render as Markdown.
  final String content;

  /// Which bubble variant this body is inside. Affects style tokens.
  final MessageBubbleKind kind;

  /// Optional base text style (overrides theme defaults).
  final TextStyle? baseStyle;

  /// Called when a user taps a link. If null, links are not interactive.
  final void Function(String text, String? href, String title)? onLinkTap;

  /// The current user's display name for self-mention highlighting.
  /// When a `@mention` matches this name (case-insensitive), it gets
  /// extra emphasis styling.
  final String? currentUserName;

  /// Called when a user taps a @mention chip. Receives the mention name
  /// (without the `@` prefix). Used for mention → profile navigation.
  final void Function(String name)? onMentionTap;

  /// Called when a user taps a #channel reference chip. Receives the channel
  /// name (without the `#` prefix). Used for channel navigation.
  final void Function(String name)? onChannelRefTap;

  /// Called when a user taps a `task #N` reference chip. Receives the task
  /// number as a string. Used for task page navigation.
  final void Function(String number)? onTaskRefTap;

  /// Called when a user taps a thread reference chip (`#channel:hexid` or
  /// `dm:@name:hexid`). Receives structured [ThreadRefData] for navigation.
  final void Function(ThreadRefData data)? onThreadRefTap;

  @override
  State<MarkdownMessageBody> createState() => _MarkdownMessageBodyState();
}

/// Static ExtensionSet — block syntaxes + inline syntaxes are constant
/// across all message bodies. Allocated once, never recreated.
final md.ExtensionSet _kExtensionSet = md.ExtensionSet(
  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
  [
    // ThreadRefSyntax before ChannelRefSyntax — "#channel:hexid" must not be
    // partially consumed as "#channel".
    ThreadRefSyntax(),
    // TaskRefSyntax before ChannelRefSyntax — "task #3" is more specific than
    // bare "#3" which would be caught by ChannelRefSyntax.
    TaskRefSyntax(),
    MentionSyntax(),
    ChannelRefSyntax(),
    md.StrikethroughSyntax(),
    ..._kGfmInlineSyntaxesWithoutAutolink,
  ],
);

class _MarkdownMessageBodyState extends State<MarkdownMessageBody> {
  // Hoisted BorderRadius for code block decoration (Scan #45).
  static final _kCodeBlockBorderRadius = BorderRadius.circular(AppSpacing.sm);

  // Cached stylesheet and builders — rebuilt only in
  // didChangeDependencies (theme change) or didUpdateWidget (kind/style change).
  late MarkdownStyleSheet _cachedStyleSheet;
  late Map<String, MarkdownElementBuilder> _cachedBuilders;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildCache();
  }

  @override
  void didUpdateWidget(covariant MarkdownMessageBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.baseStyle != widget.baseStyle ||
        oldWidget.currentUserName != widget.currentUserName ||
        oldWidget.onMentionTap != widget.onMentionTap ||
        oldWidget.onChannelRefTap != widget.onChannelRefTap ||
        oldWidget.onTaskRefTap != widget.onTaskRefTap ||
        oldWidget.onThreadRefTap != widget.onThreadRefTap) {
      _rebuildCache();
    }
  }

  void _rebuildCache() {
    final colors = Theme.of(context).extension<AppColors>()!;
    _cachedStyleSheet = _buildStyleSheet(colors);
    _cachedBuilders = {
      'pre': _ScrollableCodeBlockBuilder(
        maxHeight: _kCodeBlockMaxHeight,
        codeStyle: _cachedStyleSheet.code!,
        padding: _cachedStyleSheet.codeblockPadding!,
      ),
      'mention': MentionBuilder(
        currentUserName: widget.currentUserName,
        onMentionTap: widget.onMentionTap,
      ),
      'thread_ref': ThreadRefBuilder(
        onThreadRefTap: widget.onThreadRefTap,
      ),
      'channel_ref': ChannelRefBuilder(
        onChannelRefTap: widget.onChannelRefTap,
      ),
      'task_ref': TaskRefBuilder(
        onTaskRefTap: widget.onTaskRefTap,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      key: const ValueKey('markdown-body'),
      data: widget.content,
      styleSheet: _cachedStyleSheet,
      onTapLink: widget.onLinkTap,
      selectable: false,
      builders: _cachedBuilders,
      extensionSet: _kExtensionSet,
      // Strip images — not supported in this scope
      sizedImageBuilder: (_) => const SizedBox.shrink(),
      shrinkWrap: true,
      softLineBreak: true,
    );
  }

  MarkdownStyleSheet _buildStyleSheet(AppColors colors) {
    final isSelf = widget.kind == MessageBubbleKind.self;
    final effectiveBase = widget.baseStyle ?? AppTypography.body;

    // Text colors depend on bubble variant
    final textColor = isSelf ? colors.primaryForeground : colors.text;
    final secondaryColor = isSelf
        ? colors.primaryForeground.withValues(alpha: _kSelfSecondaryAlpha)
        : colors.textSecondary;

    // Inline code colors
    final codeBackground = isSelf
        ? colors.primaryForeground.withValues(alpha: _kSelfOverlayAlpha)
        : colors.surfaceAlt;
    final codeTextColor = isSelf ? colors.primaryForeground : colors.primary;

    // Code block colors
    final codeBlockBackground = isSelf
        ? colors.primaryForeground.withValues(alpha: _kSelfOverlayAlpha)
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
        borderRadius: _kCodeBlockBorderRadius,
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
