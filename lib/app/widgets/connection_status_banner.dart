import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Banner that shows "Reconnecting..." when the WebSocket is disconnected.
///
/// Auto-dismisses when the connection is restored. Watches
/// [realtimeServiceProvider] for connection state changes.
///
/// Place at the top of conversation/inbox page bodies.
class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO(#565 Phase B): Implement banner UI.
    // Watch realtimeServiceProvider.status, show banner when disconnected/reconnecting.
    return const SizedBox.shrink();
  }
}
