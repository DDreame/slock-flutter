import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/core/realtime/realtime_connection_state.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Grace period before showing the reconnecting banner.
/// Prevents flashing on sub-second WiFi handoffs.
const bannerGracePeriod = Duration(milliseconds: 2000);

/// Banner that shows "Reconnecting..." when the WebSocket is disconnected
/// or reconnecting. Auto-dismisses when the connection is restored.
///
/// INV-859: Implements a 2000ms grace period — the banner is NOT shown for
/// disconnects shorter than 2s. This prevents annoying flashes during
/// WiFi handoffs or brief network blips.
///
/// Watches [realtimeServiceProvider] for connection state changes.
/// Place at the top of conversation/inbox page bodies (below app bar).
class ConnectionStatusBanner extends ConsumerStatefulWidget {
  const ConnectionStatusBanner({super.key});

  @override
  ConsumerState<ConnectionStatusBanner> createState() =>
      _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState
    extends ConsumerState<ConnectionStatusBanner> {
  Timer? _graceTimer;
  bool _showBanner = false;

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(
      realtimeServiceProvider.select((s) => s.status),
    );
    final isDisconnected = status == RealtimeConnectionStatus.disconnected ||
        status == RealtimeConnectionStatus.reconnecting;

    // INV-859: Grace period logic.
    // On disconnect: start timer. On reconnect: cancel timer + hide banner.
    if (isDisconnected && !_showBanner && _graceTimer == null) {
      _graceTimer = Timer(bannerGracePeriod, () {
        if (mounted) {
          setState(() {
            _showBanner = true;
          });
        }
        _graceTimer = null;
      });
    } else if (!isDisconnected) {
      _graceTimer?.cancel();
      _graceTimer = null;
      if (_showBanner) {
        // Use post-frame callback to avoid setState during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _showBanner = false;
            });
          }
        });
      }
    }

    final colors = Theme.of(context).extension<AppColors>()!;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      offset: _showBanner ? Offset.zero : const Offset(0, -1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showBanner ? 1.0 : 0.0,
        child: _showBanner
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
                  context.l10n.connectionReconnecting,
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
