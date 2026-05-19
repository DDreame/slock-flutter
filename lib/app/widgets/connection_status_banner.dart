import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/core/realtime/realtime_connection_state.dart';

/// Banner that shows "Reconnecting..." when the WebSocket is disconnected
/// or reconnecting. Auto-dismisses when the connection is restored.
///
/// Watches [realtimeServiceProvider] for connection state changes.
/// Place at the top of conversation/inbox page bodies (below app bar).
class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      realtimeServiceProvider.select((s) => s.status),
    );
    final isDisconnected = status == RealtimeConnectionStatus.disconnected ||
        status == RealtimeConnectionStatus.reconnecting;

    final colors = Theme.of(context).extension<AppColors>()!;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      offset: isDisconnected ? Offset.zero : const Offset(0, -1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isDisconnected ? 1.0 : 0.0,
        child: isDisconnected
            ? Container(
                key: const ValueKey('connection-status-banner'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                ),
                child: Text(
                  'Reconnecting...',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
