import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/conversation/application/typing_indicator_store.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Displays a typing indicator with animated dots and descriptive text.
///
/// Watches [typingIndicatorStoreProvider] and renders nothing when no
/// users are typing. When one or more users are typing, shows an
/// animated three-dot indicator followed by "X is typing..." text.
///
/// Animate in/out: slide + fade transition (200ms) matching SummaryCard
/// pattern. The indicator slides up from below when appearing, and
/// slides back down when disappearing.
class TypingIndicatorWidget extends ConsumerStatefulWidget {
  const TypingIndicatorWidget({super.key});

  /// Build counter for rebuild-detection tests. Incremented in debug mode
  /// only via assert(); zero-cost in release builds.
  /// Reset manually in test setUp.
  @visibleForTesting
  static int debugBuildCount = 0;

  @override
  ConsumerState<TypingIndicatorWidget> createState() =>
      _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends ConsumerState<TypingIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      TypingIndicatorWidget.debugBuildCount++;
      return true;
    }());
    final activeTypers = ref.watch(
      typingIndicatorStoreProvider.select((s) => s.activeTypers),
    );

    // Drive animation based on whether anyone is typing.
    if (activeTypers.isNotEmpty) {
      _controller.forward();
    } else {
      _controller.reverse();
    }

    final l10n = context.l10n;
    final displayText = activeTypers.isEmpty
        ? ''
        : switch (activeTypers.length) {
            1 => l10n.typingIndicatorOne(activeTypers[0].displayName),
            2 => l10n.typingIndicatorTwo(
                activeTypers[0].displayName,
                activeTypers[1].displayName,
              ),
            _ => l10n.typingIndicatorSeveral,
          };

    return SizeTransition(
      sizeFactor: _fadeAnimation,
      axisAlignment: 1.0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            key: const ValueKey('typing-indicator'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // PERF-870: Only mount _AnimatedDots when someone is typing.
                // This stops the .repeat() ticker when the indicator is hidden
                // (SizeTransition collapses but previously kept child mounted).
                if (activeTypers.isNotEmpty)
                  const RepaintBoundary(
                    child: _AnimatedDots(
                      key: ValueKey('typing-dots'),
                    ),
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    displayText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three dots that animate in sequence to indicate typing activity.
class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots({super.key});

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Stagger each dot by 0.2 of the animation cycle.
            final delay = index * 0.2;
            final value = (_controller.value + delay) % 1.0;
            // Pulse: dots grow and shrink in a sine-like curve.
            final scale = 0.5 + 0.5 * _pulse(value);
            final opacity = 0.3 + 0.7 * _pulse(value);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  /// Maps [t] in [0, 1] to a pulse curve peaking at 0.5.
  double _pulse(double t) {
    if (t < 0.5) return t * 2;
    return (1 - t) * 2;
  }
}
