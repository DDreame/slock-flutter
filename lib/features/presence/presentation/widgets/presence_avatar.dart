import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';

/// A composable wrapper that overlays a status dot on any avatar widget.
///
/// Usage:
/// ```dart
/// PresenceAvatar(
///   userId: member.id,
///   child: ProfileAvatar(displayName: member.name),
/// )
/// ```
class PresenceAvatar extends ConsumerWidget {
  const PresenceAvatar({
    super.key,
    required this.userId,
    required this.child,
    this.dotSize = 10,
    this.dotBorderWidth = 2,
    this.showDot = true,
  });

  /// The user ID to track presence for.
  final String userId;

  /// The avatar widget to wrap.
  final Widget child;

  /// Diameter of the status dot.
  final double dotSize;

  /// Width of the dot's border (matches the background).
  final double dotBorderWidth;

  /// Whether to show the dot at all.
  final bool showDot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      presenceStoreProvider.select((s) => s.statusOf(userId)),
    );
    final colors = Theme.of(context).extension<AppColors>()!;

    final dotColor = switch (status) {
      UserPresenceStatus.online => colors.success,
      UserPresenceStatus.offline => colors.textTertiary,
    };

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (showDot)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              key: ValueKey('presence-dot-$userId'),
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.surface,
                  width: dotBorderWidth,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
