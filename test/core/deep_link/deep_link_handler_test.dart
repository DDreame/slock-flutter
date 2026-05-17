// ---------------------------------------------------------------------------
// #548: App Links Client Prep — Deep Link Handler
//
// Problem: Deep linking is completely non-functional on both platforms.
// GoRouter routing is correct (paths work once navigated), but there is no
// URL→GoRouter dispatch layer: no `app_links` package, no AndroidManifest
// intent-filter for HTTPS App Links, no iOS associated-domains entitlement,
// and the existing `slock://` custom scheme has no Android registration.
//
// Phase A: skip:true invariants locking the deep link handler contract.
//          A test-local _TestableDeepLinkHandler mirrors the production API
//          so assertions are real, compiled code. Phase B swaps the seam
//          for the real implementation and un-skips.
//
// Invariants verified:
// INV-LINK-PARSE-1: Deep link URLs (https://app.slock.ai/..., slock://...)
//                   parse to the correct GoRouter path + query parameters.
//                   For HTTPS links the handler uses the URI path directly.
//                   For slock:// custom scheme, the URI authority becomes the
//                   first path segment (slock://servers/s1/... → /servers/s1/…)
//                   because Dart's Uri parser treats the token after :// as
//                   the host.
// INV-LINK-DEFERRED-1: When app is not authenticated, incoming deep link is
//                      stored in pendingDeepLinkProvider and applied after
//                      login
// INV-LINK-DISPATCH-1: Deep link dispatch calls GoRouter.go() with the
//                      correct path and parameters
// ---------------------------------------------------------------------------
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';

// ---------------------------------------------------------------------------
// Test-local seam: mirrors the production DeepLinkHandler API that Phase B
// will implement in lib/core/deep_link/deep_link_handler.dart.
//
// Phase B: replace this class with the real DeepLinkHandler import and
//          swap _testAuthProvider reads for sessionStoreProvider reads.
//          Remove _FakeRouter (the real handler takes GoRouter directly).
// ---------------------------------------------------------------------------

/// Test-local auth state provider.
/// Phase B: the production handler reads from sessionStoreProvider instead.
final _testAuthProvider = StateProvider<bool>((ref) => false);

/// Minimal router interface recording go/push calls.
/// Phase B: replaced by GoRouter.
class _FakeRouter {
  _FakeRouter({this.onGo, this.onPush});
  final void Function(String path)? onGo;
  final void Function(String path)? onPush;

  void go(String path) => onGo?.call(path);
  void push(String path) => onPush?.call(path);
}

/// Test-local deep link handler seam.
///
/// Constructor mirrors the intended production API:
///   DeepLinkHandler(router: <GoRouter>, ref: <ProviderContainer>)
///
/// Auth state is read from ref (via [_testAuthProvider] in tests,
/// sessionStoreProvider in production).
///
/// Methods:
///   String? parseDeepLinkUrl(Uri uri)
///   void handleDeepLink(Uri uri)
///   void dispatchPendingDeepLink()
class _TestableDeepLinkHandler {
  _TestableDeepLinkHandler({
    required _FakeRouter router,
    required ProviderContainer ref,
  })  : _router = router,
        _ref = ref;

  final _FakeRouter _router;
  final ProviderContainer _ref;

  static const _httpsHost = 'app.slock.ai';
  static const _customScheme = 'slock';

  /// Whether the current session is authenticated.
  /// Reads from [_testAuthProvider] (test) / sessionStoreProvider (prod).
  bool get _isAuthenticated => _ref.read(_testAuthProvider);

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
      // slock://servers/s1/channels/c1 →
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
  /// If authenticated: dispatches immediately —
  ///   invite links → router.go() (replaces navigation stack)
  ///   conversation / notification links → router.push() (preserves stack)
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
    } else {
      _router.push(path);
    }
  }
}

void main() {
  // -----------------------------------------------------------------------
  // INV-LINK-PARSE-1: Deep link URL parsing
  // -----------------------------------------------------------------------
  group('INV-LINK-PARSE-1: deep link URL parsing', () {
    late _TestableDeepLinkHandler handler;

    setUp(() {
      handler = _TestableDeepLinkHandler(
        router: _FakeRouter(),
        ref: ProviderContainer(),
      );
    });

    test(
      'HTTPS invite URL parses to /invite/:token path',
      () {
        final path = handler.parseDeepLinkUrl(
          Uri.parse('https://app.slock.ai/invite/abc123'),
        );
        expect(path, '/invite/abc123');
        expect(isInviteDeepLink(path!), isTrue);
        expect(extractInviteToken(path), 'abc123');
      },
    );

    test(
      'custom scheme conversation URL parses to /servers/:sid/channels/:cid',
      () {
        final path = handler.parseDeepLinkUrl(
          Uri.parse('slock://servers/server-1/channels/channel-1'),
        );
        expect(path, '/servers/server-1/channels/channel-1');
        expect(isConversationDeepLink(path!), isTrue);
        expect(extractDeepLinkServerId(path), 'server-1');
      },
    );

    test(
      'preserves query parameters (e.g. ?messageId=) in parsed path',
      () {
        final path = handler.parseDeepLinkUrl(
          Uri.parse('slock://servers/s1/channels/c1?messageId=m1'),
        );
        expect(path, '/servers/s1/channels/c1?messageId=m1');
      },
    );

    test(
      'custom scheme DM URL parses to /servers/:sid/dms/:cid',
      () {
        final path = handler.parseDeepLinkUrl(
          Uri.parse('slock://servers/s1/dms/dm-1'),
        );
        expect(path, '/servers/s1/dms/dm-1');
        expect(isConversationDeepLink(path!), isTrue);
      },
    );

    test(
      'notification deep link URLs (threads, agents, profile) parse correctly',
      () {
        // Thread reply
        expect(
          handler.parseDeepLinkUrl(
            Uri.parse('https://app.slock.ai/servers/s1/threads/t1/replies'),
          ),
          '/servers/s1/threads/t1/replies',
        );
        expect(
          isNotificationDeepLink('/servers/s1/threads/t1/replies'),
          isTrue,
        );

        // Agent
        expect(
          handler.parseDeepLinkUrl(
            Uri.parse('slock://servers/s1/agents/a1'),
          ),
          '/servers/s1/agents/a1',
        );

        // Profile
        expect(
          handler.parseDeepLinkUrl(
            Uri.parse('https://app.slock.ai/profile/u1'),
          ),
          '/profile/u1',
        );
      },
    );

    test(
      'returns null for unrecognized URLs',
      () {
        expect(
          handler.parseDeepLinkUrl(Uri.parse('https://google.com')),
          isNull,
        );
        expect(
          handler.parseDeepLinkUrl(Uri.parse('mailto:test@example.com')),
          isNull,
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-LINK-DEFERRED-1: Deferred deep link storage
  // -----------------------------------------------------------------------
  group('INV-LINK-DEFERRED-1: deferred deep link storage', () {
    test(
      'stores invite deep link in pendingDeepLinkProvider when '
      'unauthenticated',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        // Auth state: unauthenticated (default is false).

        final handler = _TestableDeepLinkHandler(
          router: _FakeRouter(),
          ref: container,
        );

        handler.handleDeepLink(
          Uri.parse('https://app.slock.ai/invite/token-1'),
        );

        expect(
          container.read(pendingDeepLinkProvider),
          '/invite/token-1',
        );
      },
    );

    test(
      'stores conversation deep link in pendingDeepLinkProvider when '
      'session is unknown',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        // Auth state: unauthenticated (default is false).

        final handler = _TestableDeepLinkHandler(
          router: _FakeRouter(),
          ref: container,
        );

        handler.handleDeepLink(
          Uri.parse('slock://servers/s1/channels/c1?messageId=m1'),
        );

        expect(
          container.read(pendingDeepLinkProvider),
          '/servers/s1/channels/c1?messageId=m1',
        );
      },
    );

    test(
      'pending deep link is consumed (set to null) after dispatch',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Pre-seed a pending deep link.
        container.read(pendingDeepLinkProvider.notifier).state =
            '/invite/token-1';

        // Simulate authentication completing — set auth to true.
        container.read(_testAuthProvider.notifier).state = true;

        final navigatedPaths = <String>[];
        final handler = _TestableDeepLinkHandler(
          router: _FakeRouter(onGo: navigatedPaths.add),
          ref: container,
        );

        // Handler dispatches pending link AND clears it internally.
        handler.dispatchPendingDeepLink();

        // Pending link should be cleared by the handler, not by the test.
        expect(container.read(pendingDeepLinkProvider), isNull);
        expect(navigatedPaths, ['/invite/token-1']);
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-LINK-DISPATCH-1: Deep link dispatch
  // -----------------------------------------------------------------------
  group('INV-LINK-DISPATCH-1: deep link dispatch', () {
    test(
      'dispatches invite deep link via GoRouter.go() when authenticated',
      () {
        final navigatedPaths = <String>[];
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(_testAuthProvider.notifier).state = true;

        final handler = _TestableDeepLinkHandler(
          router: _FakeRouter(onGo: navigatedPaths.add),
          ref: container,
        );

        handler.handleDeepLink(
          Uri.parse('https://app.slock.ai/invite/abc123'),
        );

        expect(navigatedPaths, ['/invite/abc123']);
      },
    );

    test(
      'dispatches conversation deep link via GoRouter.push() when '
      'authenticated',
      () {
        final pushedPaths = <String>[];
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(_testAuthProvider.notifier).state = true;

        final handler = _TestableDeepLinkHandler(
          router: _FakeRouter(onPush: pushedPaths.add),
          ref: container,
        );

        handler.handleDeepLink(
          Uri.parse('slock://servers/s1/channels/c1?messageId=m1'),
        );

        expect(
          pushedPaths,
          ['/servers/s1/channels/c1?messageId=m1'],
        );
      },
    );

    test(
      'dispatches notification deep link (thread reply) via GoRouter.push()',
      () {
        final pushedPaths = <String>[];
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(_testAuthProvider.notifier).state = true;

        final handler = _TestableDeepLinkHandler(
          router: _FakeRouter(onPush: pushedPaths.add),
          ref: container,
        );

        handler.handleDeepLink(
          Uri.parse('slock://servers/s1/threads/t1/replies'),
        );

        expect(pushedPaths, ['/servers/s1/threads/t1/replies']);
      },
    );

    test(
      'does not dispatch when session is unauthenticated (stores instead)',
      () {
        final navigatedPaths = <String>[];
        final container = ProviderContainer();
        addTearDown(container.dispose);
        // Auth state: unauthenticated (default is false).

        final handler = _TestableDeepLinkHandler(
          router: _FakeRouter(
            onGo: navigatedPaths.add,
            onPush: navigatedPaths.add,
          ),
          ref: container,
        );

        handler.handleDeepLink(
          Uri.parse('slock://servers/s1/channels/c1'),
        );

        // No navigation should occur.
        expect(navigatedPaths, isEmpty);
        // Link should be stored instead.
        expect(
          container.read(pendingDeepLinkProvider),
          '/servers/s1/channels/c1',
        );
      },
    );
  });
}
