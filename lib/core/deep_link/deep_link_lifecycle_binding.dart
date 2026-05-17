import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/core/deep_link/deep_link_handler.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Lifecycle binding that listens for incoming deep links via `app_links`
/// and dispatches them through [DeepLinkHandler].
///
/// Watched in [SlockApp.build] so it lives for the app's lifetime.
/// On auth state change (unauthenticated → authenticated), dispatches
/// any pending deep link that was deferred before login.
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

  // Stream listener for foreground deep links.
  linkSub = appLinks.uriLinkStream.listen((uri) {
    handler.handleDeepLink(uri);
  });

  // Cold-start: check if the app was opened via a deep link.
  unawaited(appLinks.getInitialLink().then((uri) {
    if (uri != null) {
      handler.handleDeepLink(uri);
    }
  }));

  // Dispatch pending deep link after login.
  ref.listen<SessionState>(sessionStoreProvider, (prev, next) {
    if (prev?.isAuthenticated != true && next.isAuthenticated) {
      handler.dispatchPendingDeepLink();
    }
  });

  ref.onDispose(() {
    unawaited(linkSub?.cancel());
  });
});
