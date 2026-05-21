import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/core/deep_link/deep_link_handler.dart';

/// Guards against duplicate dispatch when Android OEMs re-emit the cold-start
/// intent on `uriLinkStream` after `getInitialLink()` already returned it
/// (or vice-versa when the stream fires before the Future resolves).
///
/// The guard tracks which cold-start URI has already been dispatched from
/// either source, ensuring exactly one dispatch regardless of timing order.
/// After the first stream event, all subsequent stream events pass through
/// unconditionally (they represent legitimate foreground deep links).
@visibleForTesting
class DeepLinkDedupGuard {
  Uri? _coldStartDispatched;
  bool _firstStreamConsumed = false;

  /// Called for each stream event. Returns `true` if the event should be
  /// dispatched, `false` if it's a duplicate of the cold-start URI.
  ///
  /// Only the first stream event participates in dedup. All subsequent
  /// stream events pass through unconditionally.
  bool shouldDispatchStream(Uri uri) {
    if (_firstStreamConsumed) return true;
    _firstStreamConsumed = true;
    if (_coldStartDispatched != null && uri == _coldStartDispatched) {
      return false;
    }
    _coldStartDispatched ??= uri;
    return true;
  }

  /// Called when `getInitialLink()` resolves with a non-null URI. Returns
  /// `true` if the initial URI should be dispatched, `false` if the stream
  /// already dispatched the same URI.
  bool shouldDispatchInitial(Uri uri) {
    if (_coldStartDispatched != null && uri == _coldStartDispatched) {
      return false;
    }
    _coldStartDispatched = uri;
    return true;
  }
}

/// Lifecycle binding that listens for incoming deep links via `app_links`
/// and dispatches them through [DeepLinkHandler].
///
/// Watched in [SlockApp.build] so it lives for the app's lifetime.
/// Handles incoming deep links only (stream + cold-start). Pending
/// deferred links are consumed by `app_router.dart`'s existing redirect
/// logic which has full bootstrap/server guards.
///
/// **Dedup guard (#694):** On some Android OEMs, `uriLinkStream` re-emits the
/// cold-start launch intent. We capture the initial URI and skip the first
/// stream event if it matches, preventing duplicate route pushes.
final deepLinkLifecycleBindingProvider = Provider<void>((ref) {
  final router = ref.watch(appRouterProvider);
  final container = ref.container;

  final handler = DeepLinkHandler(
    router: router,
    ref: container,
  );

  // Listen for incoming deep links (both cold-start and foreground).
  final appLinks = AppLinks();
  StreamSubscription<Uri>? linkSub;

  final dedup = DeepLinkDedupGuard();

  // Stream listener for foreground deep links.
  linkSub = appLinks.uriLinkStream.listen((uri) {
    if (dedup.shouldDispatchStream(uri)) {
      handler.handleDeepLink(uri);
    }
  });

  // Cold-start: check if the app was opened via a deep link.
  unawaited(appLinks.getInitialLink().then((uri) {
    if (uri != null && dedup.shouldDispatchInitial(uri)) {
      handler.handleDeepLink(uri);
    }
  }));

  // NOTE: Pending deep link dispatch after login is handled by
  // app_router.dart's existing redirect logic, which waits for
  // appReadyProvider + server membership before dispatching.
  // This binding only receives and stores incoming links.

  ref.onDispose(() {
    unawaited(linkSub?.cancel());
  });
});
