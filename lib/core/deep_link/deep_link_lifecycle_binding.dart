import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/core/deep_link/deep_link_handler.dart';

/// Guards against duplicate dispatch when Android OEMs re-emit the cold-start
/// intent on `uriLinkStream` after `getInitialLink()` already returned it.
///
/// Algorithm:
/// 1. Record the initial URI from [setInitialUri].
/// 2. On first stream event ([shouldDispatch]), compare with the initial URI.
///    If match → return false (skip). Otherwise → return true.
/// 3. All subsequent stream events → return true unconditionally.
@visibleForTesting
class DeepLinkDedupGuard {
  Uri? _initialUri;
  bool _consumed = false;

  /// Record the cold-start URI. Call after [getInitialLink] resolves.
  void setInitialUri(Uri? uri) {
    if (uri != null) {
      _initialUri = uri;
    } else {
      // No cold-start link — skip dedup on subsequent stream events.
      _consumed = true;
    }
  }

  /// Returns `true` if the stream event [uri] should be dispatched, `false`
  /// if it's a duplicate of the cold-start URI and should be skipped.
  bool shouldDispatch(Uri uri) {
    if (_consumed) return true;
    _consumed = true;
    return _initialUri == null || uri != _initialUri;
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
    if (dedup.shouldDispatch(uri)) {
      handler.handleDeepLink(uri);
    }
  });

  // Cold-start: check if the app was opened via a deep link.
  unawaited(appLinks.getInitialLink().then((uri) {
    dedup.setInitialUri(uri);
    if (uri != null) {
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
