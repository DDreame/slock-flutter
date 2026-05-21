import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Handles incoming deep links by parsing URLs and dispatching to GoRouter.
///
/// Supports two URL schemes:
/// - HTTPS App Links: `https://app.slock.ai/invite/TOKEN`, etc.
/// - Custom scheme: `slock://servers/S1/channels/C1`, etc.
///
/// When the user is not authenticated, links are deferred to
/// [pendingDeepLinkProvider] and dispatched after login via
/// [dispatchPendingDeepLink].
class DeepLinkHandler {
  DeepLinkHandler({
    required GoRouter router,
    required ProviderContainer ref,
  })  : _router = router,
        _ref = ref;

  final GoRouter _router;
  final ProviderContainer _ref;

  static const _httpsHost = 'app.slock.ai';
  static const _customScheme = 'slock';

  /// Whether the current session is authenticated.
  bool get _isAuthenticated => _ref.read(sessionStoreProvider).isAuthenticated;

  /// Parses a deep link [uri] into a GoRouter-compatible path string.
  ///
  /// For HTTPS links (host = app.slock.ai): returns the URI path directly,
  /// appending query parameters if present.
  ///
  /// For slock:// custom scheme: Dart's [Uri] parser treats the token after
  /// `://` as the host/authority, so `slock://servers/s1/channels/c1` yields
  /// host='servers', path='/s1/channels/c1'. The handler reconstructs the
  /// full GoRouter path by prepending `/<host>` to the path.
  ///
  /// Returns null for unrecognized schemes/hosts.
  String? parseDeepLinkUrl(Uri uri) {
    if (uri.scheme == 'https' && uri.host == _httpsHost) {
      final path = uri.path;
      if (path.isEmpty) return null;
      if (uri.query.isNotEmpty) return '$path?${uri.query}';
      return path;
    }

    if (uri.scheme == _customScheme) {
      // slock://servers/s1/channels/c1 ->
      //   host = 'servers', path = '/s1/channels/c1'
      //   result = '/servers/s1/channels/c1'
      final host = uri.host;
      if (host.isEmpty) return null;
      final path = '/$host${uri.path}';
      if (uri.query.isNotEmpty) return '$path?${uri.query}';
      return path;
    }

    return null;
  }

  /// Handles an incoming deep link [uri].
  ///
  /// If not authenticated: stores the parsed path in
  /// [pendingDeepLinkProvider] for post-login consumption.
  ///
  /// If authenticated: dispatches immediately --
  ///   invite links -> router.go() (replaces navigation stack)
  ///   conversation / notification links -> router.push() (preserves stack)
  void handleDeepLink(Uri uri) {
    final path = parseDeepLinkUrl(uri);
    if (path == null) return;

    if (!_isAuthenticated) {
      _ref.read(pendingDeepLinkProvider.notifier).state = path;
      return;
    }

    _dispatch(path);
  }

  /// Dispatches the pending deep link stored in [pendingDeepLinkProvider].
  ///
  /// Called after authentication completes. Reads the pending path, clears
  /// the provider, then dispatches. No-op if no pending link exists.
  void dispatchPendingDeepLink() {
    final pending = _ref.read(pendingDeepLinkProvider);
    if (pending == null) return;

    // Clear before dispatch to prevent re-dispatch on redirect loops.
    _ref.read(pendingDeepLinkProvider.notifier).state = null;
    _dispatch(pending);
  }

  void _dispatch(String path) {
    if (isInviteDeepLink(path)) {
      _router.go(path);
    } else if (!_isCurrentRoute(path)) {
      _router.push(path);
    }
  }

  bool _isCurrentRoute(String path) {
    final targetUri = Uri.parse(path);
    final currentUri = _router.routeInformationProvider.value.uri;
    return currentUri.path == targetUri.path;
  }
}
