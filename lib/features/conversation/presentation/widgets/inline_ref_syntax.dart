import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';

/// Data class for parsed thread reference info.
///
/// Used by [ThreadRefBuilder] and the fallback span builder to pass
/// structured data to the tap callback.
class ThreadRefData {
  const ThreadRefData({
    required this.targetName,
    required this.messageShortId,
    required this.isDm,
  });

  /// Channel name (for channel threads) or peer @handle (for DM threads).
  final String targetName;

  /// The 6-8 hex char short ID of the parent message.
  final String messageShortId;

  /// Whether this is a DM thread (`dm:@name:hexid`) vs channel thread.
  final bool isDm;
}

/// Inline syntax that matches thread reference patterns in message text.
///
/// Two patterns:
/// - Channel thread: `#channel-name:a1b2c3d4` (channel + colon + 6-8 hex ID)
/// - DM thread: `dm:@username:a1b2c3d4` (dm + @handle + colon + 6-8 hex ID)
///
/// Must be registered BEFORE [ChannelRefSyntax] so that `#foo:abc123` is not
/// partially consumed as a channel ref `#foo`.
///
/// Produces an `md.Element` with tag `thread_ref` containing attributes:
/// - `target`: channel name or DM peer name
/// - `messageId`: the hex short ID
/// - `isDm`: "true" or "false"
class ThreadRefSyntax extends md.InlineSyntax {
  ThreadRefSyntax()
      : super(
          r'(?:#([a-zA-Z][\w-]+):([\da-f]{6,8})(?![\da-f])|dm:@([\w][\w.\-]*):([\da-f]{6,8})(?![\da-f]))',
          caseSensitive: false,
        );

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    final start = startMatchPos ?? parser.pos;
    // Must be at start of string or preceded by whitespace/punctuation.
    if (start > 0) {
      final preceding = parser.source.codeUnitAt(start - 1);
      if (_isWordCharOrDot(preceding)) {
        return false;
      }
    }
    return super.tryMatch(parser, startMatchPos);
  }

  static bool _isWordCharOrDot(int codeUnit) {
    return (codeUnit >= 48 && codeUnit <= 57) ||
        (codeUnit >= 65 && codeUnit <= 90) ||
        codeUnit == 95 ||
        (codeUnit >= 97 && codeUnit <= 122) ||
        codeUnit == 46;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    // Group layout:
    // match[1] = channel name (channel thread)
    // match[2] = hex ID (channel thread)
    // match[3] = DM peer name (DM thread)
    // match[4] = hex ID (DM thread)
    final channelName = match.group(1);
    final channelMsgId = match.group(2);
    final dmPeerName = match.group(3);
    final dmMsgId = match.group(4);

    final String target;
    final String messageId;
    final bool isDm;

    if (channelName != null && channelMsgId != null) {
      target = channelName;
      messageId = channelMsgId;
      isDm = false;
    } else if (dmPeerName != null && dmMsgId != null) {
      target = dmPeerName;
      messageId = dmMsgId;
      isDm = true;
    } else {
      return false;
    }

    final fullText = match.group(0)!;
    final element = md.Element.text('thread_ref', fullText);
    element.attributes['target'] = target;
    element.attributes['messageId'] = messageId;
    element.attributes['isDm'] = isDm.toString();
    parser.addNode(element);
    return true;
  }
}

/// Inline syntax that matches `#channel-name` patterns in message text.
///
/// Matches: `#` followed by one or more word characters, hyphens, or dots.
/// The match is bounded: it must appear at the start of the string or after
/// a whitespace/punctuation character.
///
/// Produces an `md.Element` with tag `channel_ref` containing the channel
/// name (without the `#` prefix) as an attribute.
class ChannelRefSyntax extends md.InlineSyntax {
  ChannelRefSyntax() : super(r'#([a-zA-Z][\w.\-]*)');

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    final start = startMatchPos ?? parser.pos;
    // Channel ref must be at start of string or preceded by
    // whitespace/punctuation — not a word character or dot.
    if (start > 0) {
      final preceding = parser.source.codeUnitAt(start - 1);
      if (_isWordCharOrDot(preceding)) {
        return false;
      }
    }
    return super.tryMatch(parser, startMatchPos);
  }

  /// Returns true if the code unit is a word character [a-zA-Z0-9_] or dot.
  static bool _isWordCharOrDot(int codeUnit) {
    // 0-9: 48-57, A-Z: 65-90, _: 95, a-z: 97-122, .: 46
    return (codeUnit >= 48 && codeUnit <= 57) ||
        (codeUnit >= 65 && codeUnit <= 90) ||
        codeUnit == 95 ||
        (codeUnit >= 97 && codeUnit <= 122) ||
        codeUnit == 46;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final channelName = match.group(1)!;
    final element = md.Element.text('channel_ref', '#$channelName');
    element.attributes['name'] = channelName;
    parser.addNode(element);
    return true;
  }
}

/// Inline syntax that matches `task #N` patterns in message text.
///
/// Matches: the literal word `task` (case-insensitive) followed by optional
/// whitespace and `#` then one or more digits.
///
/// Produces an `md.Element` with tag `task_ref` containing the task number
/// as an attribute.
class TaskRefSyntax extends md.InlineSyntax {
  TaskRefSyntax()
      : super(r'task\s*#(\d+)(?![a-zA-Z0-9_\-])', caseSensitive: false);

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    final start = startMatchPos ?? parser.pos;
    // Task ref must be at start of string or preceded by whitespace/punctuation.
    if (start > 0) {
      final preceding = parser.source.codeUnitAt(start - 1);
      if (_isWordChar(preceding)) {
        return false;
      }
    }
    return super.tryMatch(parser, startMatchPos);
  }

  /// Returns true if the code unit is a word character [a-zA-Z0-9_].
  static bool _isWordChar(int codeUnit) {
    return (codeUnit >= 48 && codeUnit <= 57) ||
        (codeUnit >= 65 && codeUnit <= 90) ||
        codeUnit == 95 ||
        (codeUnit >= 97 && codeUnit <= 122);
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final taskNumber = match.group(1)!;
    final fullText = match.group(0)!;
    final element = md.Element.text('task_ref', fullText);
    element.attributes['number'] = taskNumber;
    parser.addNode(element);
    return true;
  }
}

/// Element builder that renders `channel_ref` elements as styled inline chips.
///
/// When [onChannelRefTap] is provided, tapping a channel ref invokes the
/// callback with the channel name (without the `#` prefix).
class ChannelRefBuilder extends MarkdownElementBuilder {
  ChannelRefBuilder({this.onChannelRefTap});

  /// Called when a channel ref chip is tapped. Receives the channel name
  /// (without the `#` prefix).
  final void Function(String name)? onChannelRefTap;

  /// Colors reference — set during visitElementAfterWithContext from context.
  AppColors? _colors;
  Color? _chipBackground;

  /// Exposes the cached chip background for identity testing.
  @visibleForTesting
  Color? get chipBackground => _chipBackground;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    _colors ??= Theme.of(context).extension<AppColors>();
    final colors = _colors!;
    _chipBackground ??= colors.primary.withValues(alpha: 0.1);
    final name = element.attributes['name'] ?? '';

    final style =
        (preferredStyle ?? parentStyle ?? AppTypography.body).copyWith(
      color: colors.primary,
      fontWeight: FontWeight.w600,
      backgroundColor: _chipBackground,
    );

    final child = Text.rich(
      TextSpan(text: '#$name', style: style),
    );

    if (onChannelRefTap == null) return child;

    return Semantics(
      button: true,
      label: '#$name',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('channel-ref-tap-$name'),
        onTap: () => onChannelRefTap!(name),
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}

/// Element builder that renders `task_ref` elements as styled inline chips.
///
/// When [onTaskRefTap] is provided, tapping a task ref invokes the
/// callback with the task number string.
class TaskRefBuilder extends MarkdownElementBuilder {
  TaskRefBuilder({this.onTaskRefTap});

  /// Called when a task ref chip is tapped. Receives the task number as
  /// a string (e.g. "42").
  final void Function(String number)? onTaskRefTap;

  /// Colors reference — set during visitElementAfterWithContext from context.
  AppColors? _colors;
  Color? _chipBackground;

  /// Exposes the cached chip background for identity testing.
  @visibleForTesting
  Color? get chipBackground => _chipBackground;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    _colors ??= Theme.of(context).extension<AppColors>();
    final colors = _colors!;
    _chipBackground ??= colors.primary.withValues(alpha: 0.1);
    final number = element.attributes['number'] ?? '';

    final style =
        (preferredStyle ?? parentStyle ?? AppTypography.body).copyWith(
      color: colors.primary,
      fontWeight: FontWeight.w600,
      backgroundColor: _chipBackground,
    );

    final child = Text.rich(
      TextSpan(text: 'task #$number', style: style),
    );

    if (onTaskRefTap == null) return child;

    return Semantics(
      button: true,
      label: 'task #$number',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('task-ref-tap-$number'),
        onTap: () => onTaskRefTap!(number),
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}

/// Element builder that renders `thread_ref` elements as styled inline chips.
///
/// Displays `#channel:hexid` or `dm:@name:hexid` as a tappable chip.
/// When [onThreadRefTap] is provided, tapping invokes the callback with
/// structured [ThreadRefData].
class ThreadRefBuilder extends MarkdownElementBuilder {
  ThreadRefBuilder({this.onThreadRefTap});

  /// Called when a thread ref chip is tapped. Receives structured thread
  /// reference data for navigation.
  final void Function(ThreadRefData data)? onThreadRefTap;

  /// Colors reference — set during visitElementAfterWithContext from context.
  AppColors? _colors;
  Color? _chipBackground;

  /// Exposes the cached chip background for identity testing.
  @visibleForTesting
  Color? get chipBackground => _chipBackground;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    _colors ??= Theme.of(context).extension<AppColors>();
    final colors = _colors!;
    _chipBackground ??= colors.primary.withValues(alpha: 0.1);
    final target = element.attributes['target'] ?? '';
    final messageId = element.attributes['messageId'] ?? '';
    final isDm = element.attributes['isDm'] == 'true';

    final displayText = isDm ? 'dm:@$target:$messageId' : '#$target:$messageId';

    final style =
        (preferredStyle ?? parentStyle ?? AppTypography.body).copyWith(
      color: colors.primary,
      fontWeight: FontWeight.w600,
      backgroundColor: _chipBackground,
    );

    final child = Text.rich(
      TextSpan(text: displayText, style: style),
    );

    if (onThreadRefTap == null) return child;

    final data = ThreadRefData(
      targetName: target,
      messageShortId: messageId,
      isDm: isDm,
    );

    return Semantics(
      button: true,
      label: displayText,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('thread-ref-tap-$target-$messageId'),
        onTap: () => onThreadRefTap!(data),
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}

/// Compiled channel-ref pattern shared by [buildInlineRefAwareSpan].
///
/// Matches `#channel-name` at word boundaries. Promoted to module-level
/// constant to avoid per-call [RegExp] allocation on a hot render path.
@visibleForTesting
final channelRefSpanRegex = RegExp(r'(?<![\w.])#([a-zA-Z][\w.\-]*)');

/// Compiled task-ref pattern shared by [buildInlineRefAwareSpan].
///
/// Matches `task #N` (case-insensitive) at word boundaries.
@visibleForTesting
final taskRefSpanRegex =
    RegExp(r'(?<!\w)task\s*#(\d+)(?![a-zA-Z0-9_\-])', caseSensitive: false);

/// Compiled thread-ref pattern shared by [buildInlineRefAwareSpan].
///
/// Matches `#channel-name:hexid` (channel thread) and `dm:@name:hexid`
/// (DM thread) at word boundaries.
@visibleForTesting
final threadRefSpanRegex = RegExp(
  r'(?<![\w.])(?:#([a-zA-Z][\w-]+):([\da-f]{6,8})(?![\da-f])|dm:@([\w][\w.\-]*):([\da-f]{6,8})(?![\da-f]))',
  caseSensitive: false,
);

/// Combined pattern that matches mentions, thread refs, channel refs, and
/// task refs.
///
/// Group layout (thread refs BEFORE channel refs to prevent partial consumption):
/// - Group 1: mention name (from `@name`)
/// - Group 2: channel thread target (from `#channel:hexid`)
/// - Group 3: channel thread message ID
/// - Group 4: DM thread peer name (from `dm:@name:hexid`)
/// - Group 5: DM thread message ID
/// - Group 6: channel name (from `#channel`)
/// - Group 7: task number (from `task #N`)
@visibleForTesting
final inlineRefCombinedRegex = RegExp(
  // Mention | channel thread | DM thread | channel ref | task ref
  r'(?<![\w.])@([\w][\w.\-]*)'
  r'|(?<![\w.])#([a-zA-Z][\w-]+):([\da-f]{6,8})(?![\da-f])'
  r'|(?<![\w.])dm:@([\w][\w.\-]*):([\da-f]{6,8})(?![\da-f])'
  r'|(?<![\w.])#([a-zA-Z][\w.\-]*)'
  r'|(?<!\w)task\s*#(\d+)(?![a-zA-Z0-9_\-])',
  caseSensitive: false,
);

/// Parses message text for @mentions, thread refs, #channel refs, and
/// task #N refs, returning styled [TextSpan] children.
///
/// Used in the search-highlight fallback path where Markdown rendering
/// is bypassed. Each inline reference type is styled distinctly.
///
/// When tap callbacks are provided, [TapGestureRecognizer]s are attached.
/// Created recognizers are appended to [createdRecognizers] when provided,
/// so the caller can track and dispose them on rebuild/unmount.
TextSpan buildInlineRefAwareSpan({
  required String text,
  required TextStyle? baseStyle,
  required Color mentionColor,
  required Color mentionBackground,
  required Color selfMentionColor,
  required Color selfMentionBackground,
  required Color refColor,
  required Color refBackground,
  String? currentUserName,
  String highlightQuery = '',
  Color? highlightColor,
  void Function(String name)? onMentionTap,
  void Function(String name)? onChannelRefTap,
  void Function(String number)? onTaskRefTap,
  void Function(ThreadRefData data)? onThreadRefTap,
  List<GestureRecognizer>? createdRecognizers,
}) {
  final matches = inlineRefCombinedRegex.allMatches(text).toList();

  if (matches.isEmpty) {
    if (highlightQuery.isNotEmpty && highlightColor != null) {
      return _buildHighlightedRefSpan(
          text, highlightQuery, baseStyle, highlightColor);
    }
    return TextSpan(text: text, style: baseStyle);
  }

  final spans = <InlineSpan>[];
  final currentUserNameLower = currentUserName?.toLowerCase();
  var lastEnd = 0;

  for (final match in matches) {
    // Text before the match.
    if (match.start > lastEnd) {
      final before = text.substring(lastEnd, match.start);
      if (highlightQuery.isNotEmpty && highlightColor != null) {
        spans.addAll(
          _buildHighlightedRefSpan(
                      before, highlightQuery, baseStyle, highlightColor)
                  .children ??
              [TextSpan(text: before, style: baseStyle)],
        );
      } else {
        spans.add(TextSpan(text: before, style: baseStyle));
      }
    }

    final mentionName = match.group(1);
    final channelThreadTarget = match.group(2);
    final channelThreadMsgId = match.group(3);
    final dmThreadPeer = match.group(4);
    final dmThreadMsgId = match.group(5);
    final channelName = match.group(6);
    final taskNumber = match.group(7);

    if (mentionName != null) {
      // @mention
      final isSelf = currentUserNameLower != null &&
          mentionName.toLowerCase() == currentUserNameLower;
      final mentionStyle = (baseStyle ?? const TextStyle()).copyWith(
        color: isSelf ? selfMentionColor : mentionColor,
        fontWeight: FontWeight.w600,
        backgroundColor: isSelf ? selfMentionBackground : mentionBackground,
      );
      TapGestureRecognizer? recognizer;
      if (onMentionTap != null) {
        recognizer = TapGestureRecognizer()
          ..onTap = () => onMentionTap(mentionName);
        createdRecognizers?.add(recognizer);
      }
      spans.add(TextSpan(
        text: '@$mentionName',
        style: mentionStyle,
        recognizer: recognizer,
      ));
    } else if (channelThreadTarget != null && channelThreadMsgId != null) {
      // #channel:hexid (channel thread)
      final refStyle = (baseStyle ?? const TextStyle()).copyWith(
        color: refColor,
        fontWeight: FontWeight.w600,
        backgroundColor: refBackground,
      );
      TapGestureRecognizer? recognizer;
      if (onThreadRefTap != null) {
        final data = ThreadRefData(
          targetName: channelThreadTarget,
          messageShortId: channelThreadMsgId,
          isDm: false,
        );
        recognizer = TapGestureRecognizer()..onTap = () => onThreadRefTap(data);
        createdRecognizers?.add(recognizer);
      }
      spans.add(TextSpan(
        text: '#$channelThreadTarget:$channelThreadMsgId',
        style: refStyle,
        recognizer: recognizer,
      ));
    } else if (dmThreadPeer != null && dmThreadMsgId != null) {
      // dm:@name:hexid (DM thread)
      final refStyle = (baseStyle ?? const TextStyle()).copyWith(
        color: refColor,
        fontWeight: FontWeight.w600,
        backgroundColor: refBackground,
      );
      TapGestureRecognizer? recognizer;
      if (onThreadRefTap != null) {
        final data = ThreadRefData(
          targetName: dmThreadPeer,
          messageShortId: dmThreadMsgId,
          isDm: true,
        );
        recognizer = TapGestureRecognizer()..onTap = () => onThreadRefTap(data);
        createdRecognizers?.add(recognizer);
      }
      spans.add(TextSpan(
        text: 'dm:@$dmThreadPeer:$dmThreadMsgId',
        style: refStyle,
        recognizer: recognizer,
      ));
    } else if (channelName != null) {
      // #channel
      final refStyle = (baseStyle ?? const TextStyle()).copyWith(
        color: refColor,
        fontWeight: FontWeight.w600,
        backgroundColor: refBackground,
      );
      TapGestureRecognizer? recognizer;
      if (onChannelRefTap != null) {
        recognizer = TapGestureRecognizer()
          ..onTap = () => onChannelRefTap(channelName);
        createdRecognizers?.add(recognizer);
      }
      spans.add(TextSpan(
        text: '#$channelName',
        style: refStyle,
        recognizer: recognizer,
      ));
    } else if (taskNumber != null) {
      // task #N
      final refStyle = (baseStyle ?? const TextStyle()).copyWith(
        color: refColor,
        fontWeight: FontWeight.w600,
        backgroundColor: refBackground,
      );
      TapGestureRecognizer? recognizer;
      if (onTaskRefTap != null) {
        recognizer = TapGestureRecognizer()
          ..onTap = () => onTaskRefTap(taskNumber);
        createdRecognizers?.add(recognizer);
      }
      spans.add(TextSpan(
        text: match.group(0)!,
        style: refStyle,
        recognizer: recognizer,
      ));
    }

    lastEnd = match.end;
  }

  // Remaining text after last match.
  if (lastEnd < text.length) {
    final remaining = text.substring(lastEnd);
    if (highlightQuery.isNotEmpty && highlightColor != null) {
      spans.addAll(
        _buildHighlightedRefSpan(
                    remaining, highlightQuery, baseStyle, highlightColor)
                .children ??
            [TextSpan(text: remaining, style: baseStyle)],
      );
    } else {
      spans.add(TextSpan(text: remaining, style: baseStyle));
    }
  }

  return TextSpan(children: spans);
}

/// Simple highlighted text span helper for inline ref aware span.
TextSpan _buildHighlightedRefSpan(
  String text,
  String query,
  TextStyle? baseStyle,
  Color highlightColor,
) {
  if (query.isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }

  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final spans = <InlineSpan>[];
  var lastEnd = 0;

  var index = lowerText.indexOf(lowerQuery);
  while (index != -1) {
    if (index > lastEnd) {
      spans.add(
          TextSpan(text: text.substring(lastEnd, index), style: baseStyle));
    }
    spans.add(TextSpan(
      text: text.substring(index, index + query.length),
      style: (baseStyle ?? const TextStyle()).copyWith(
        backgroundColor: highlightColor,
        fontWeight: FontWeight.bold,
      ),
    ));
    lastEnd = index + query.length;
    index = lowerText.indexOf(lowerQuery, lastEnd);
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
  }

  if (spans.isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }
  return TextSpan(children: spans);
}
