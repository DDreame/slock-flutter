import 'package:flutter/material.dart';

/// Default quick reactions shown in the reaction bar.
const kQuickReactions = ['👍', '❤️', '😂', '😮', '🙏'];

/// A floating quick reaction bar that appears above a message after
/// right-swipe gesture. Shows 5 curated emoji plus a "+" button to
/// open the full emoji picker.
///
/// Usage:
/// ```dart
/// showQuickReactionBar(
///   context: context,
///   anchorRect: messageGlobalRect,
///   onReaction: (emoji) => store.addReaction(messageId, emoji),
///   onOpenPicker: () => showEmojiPicker(...),
/// );
/// ```
void showQuickReactionBar({
  required BuildContext context,
  required Rect anchorRect,
  required void Function(String emoji) onReaction,
  required VoidCallback onOpenPicker,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _QuickReactionBarOverlay(
      anchorRect: anchorRect,
      onReaction: (emoji) {
        entry.remove();
        onReaction(emoji);
      },
      onOpenPicker: () {
        entry.remove();
        onOpenPicker();
      },
      onDismiss: () {
        entry.remove();
      },
    ),
  );

  overlay.insert(entry);
}

class _QuickReactionBarOverlay extends StatefulWidget {
  const _QuickReactionBarOverlay({
    required this.anchorRect,
    required this.onReaction,
    required this.onOpenPicker,
    required this.onDismiss,
  });

  final Rect anchorRect;
  final void Function(String emoji) onReaction;
  final VoidCallback onOpenPicker;
  final VoidCallback onDismiss;

  @override
  State<_QuickReactionBarOverlay> createState() =>
      _QuickReactionBarOverlayState();
}

class _QuickReactionBarOverlayState extends State<_QuickReactionBarOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final barWidth = (kQuickReactions.length + 1) * 44.0 + 16;

    // Position above the message, centered horizontally on the anchor.
    var left = widget.anchorRect.center.dx - barWidth / 2;
    // Clamp to screen edges with padding.
    left = left.clamp(8.0, screenSize.width - barWidth - 8.0);

    // Place above the message (8px gap).
    var top = widget.anchorRect.top - 52;
    // If not enough space above, place below.
    if (top < MediaQuery.paddingOf(context).top + 8) {
      top = widget.anchorRect.bottom + 8;
    }

    return Stack(
      children: [
        // Dismiss scrim — tap anywhere outside to close.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        // Reaction bar.
        Positioned(
          left: left,
          top: top,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: Alignment.center,
              child: Material(
                key: const ValueKey('quick-reaction-bar'),
                elevation: 8,
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context).colorScheme.surface,
                surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final emoji in kQuickReactions)
                        _ReactionButton(
                          key: ValueKey('quick-reaction-$emoji'),
                          emoji: emoji,
                          onTap: () => widget.onReaction(emoji),
                        ),
                      _MoreButton(
                        key: const ValueKey('quick-reaction-more'),
                        onTap: widget.onOpenPicker,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    super.key,
    required this.emoji,
    required this.onTap,
  });

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: emoji,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 22),
              semanticsLabel: '',
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'More reactions',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Icon(
              Icons.add_circle_outline,
              size: 22,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
