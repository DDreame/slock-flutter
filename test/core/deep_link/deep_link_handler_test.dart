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
// Phase B: Implement DeepLinkHandler, wire app_links, configure platform
//          manifests, un-skip.
//
// Invariants verified:
// INV-LINK-PARSE-1: Deep link URLs (https://app.slock.ai/..., slock://...)
//                   parse to the correct GoRouter path + query parameters
// INV-LINK-DEFERRED-1: When app is not authenticated, incoming deep link is
//                      stored in pendingDeepLinkProvider and applied after
//                      login
// INV-LINK-DISPATCH-1: Deep link dispatch calls GoRouter.go() with the
//                      correct path and parameters
// ---------------------------------------------------------------------------
// ignore: unused_import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: unused_import
import 'package:go_router/go_router.dart';
// ignore: unused_import
import 'package:slock_app/app/router/pending_deep_link_provider.dart';

// Phase B will add:
// import 'package:slock_app/core/deep_link/deep_link_handler.dart';

void main() {
  // -----------------------------------------------------------------------
  // INV-LINK-PARSE-1: Deep link URL parsing
  //
  // The DeepLinkHandler must convert both HTTPS App Link URLs and custom-
  // scheme URLs into GoRouter-compatible paths. The handler strips the
  // scheme + host, preserves the path and query parameters.
  //
  // After Phase B: DeepLinkHandler.parseDeepLinkUrl(uri) returns the
  // GoRouter path string for any recognized deep link URL.
  // -----------------------------------------------------------------------
  group('INV-LINK-PARSE-1: deep link URL parsing', () {
    test(
      'HTTPS invite URL parses to /invite/:token path',
      skip: true,
      () {
        // Phase B:
        // final handler = DeepLinkHandler();
        // final path = handler.parseDeepLinkUrl(
        //   Uri.parse('https://app.slock.ai/invite/abc123'),
        // );
        // expect(path, '/invite/abc123');
        // expect(isInviteDeepLink(path!), isTrue);
        // expect(extractInviteToken(path), 'abc123');
      },
    );

    test(
      'custom scheme conversation URL parses to /servers/:sid/channels/:cid',
      skip: true,
      () {
        // Phase B:
        // final handler = DeepLinkHandler();
        // final path = handler.parseDeepLinkUrl(
        //   Uri.parse('slock://servers/server-1/channels/channel-1'),
        // );
        // expect(path, '/servers/server-1/channels/channel-1');
        // expect(isConversationDeepLink(path!), isTrue);
        // expect(extractDeepLinkServerId(path), 'server-1');
      },
    );

    test(
      'preserves query parameters (e.g. ?messageId=) in parsed path',
      skip: true,
      () {
        // Phase B:
        // final handler = DeepLinkHandler();
        // final path = handler.parseDeepLinkUrl(
        //   Uri.parse('slock://servers/s1/channels/c1?messageId=m1'),
        // );
        // expect(path, '/servers/s1/channels/c1?messageId=m1');
      },
    );

    test(
      'custom scheme DM URL parses to /servers/:sid/dms/:cid',
      skip: true,
      () {
        // Phase B:
        // final handler = DeepLinkHandler();
        // final path = handler.parseDeepLinkUrl(
        //   Uri.parse('slock://servers/s1/dms/dm-1'),
        // );
        // expect(path, '/servers/s1/dms/dm-1');
        // expect(isConversationDeepLink(path!), isTrue);
      },
    );

    test(
      'notification deep link URLs (threads, agents, profile) parse correctly',
      skip: true,
      () {
        // Phase B:
        // final handler = DeepLinkHandler();
        //
        // // Thread reply
        // expect(
        //   handler.parseDeepLinkUrl(
        //     Uri.parse('https://app.slock.ai/servers/s1/threads/t1/replies'),
        //   ),
        //   '/servers/s1/threads/t1/replies',
        // );
        // expect(
        //   isNotificationDeepLink('/servers/s1/threads/t1/replies'),
        //   isTrue,
        // );
        //
        // // Agent
        // expect(
        //   handler.parseDeepLinkUrl(
        //     Uri.parse('slock://servers/s1/agents/a1'),
        //   ),
        //   '/servers/s1/agents/a1',
        // );
        //
        // // Profile
        // expect(
        //   handler.parseDeepLinkUrl(
        //     Uri.parse('https://app.slock.ai/profile/u1'),
        //   ),
        //   '/profile/u1',
        // );
      },
    );

    test(
      'returns null for unrecognized URLs',
      skip: true,
      () {
        // Phase B:
        // final handler = DeepLinkHandler();
        // expect(
        //   handler.parseDeepLinkUrl(Uri.parse('https://google.com')),
        //   isNull,
        // );
        // expect(
        //   handler.parseDeepLinkUrl(Uri.parse('mailto:test@example.com')),
        //   isNull,
        // );
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-LINK-DEFERRED-1: Deferred deep link storage
  //
  // When the app is not authenticated (session status is unknown or
  // unauthenticated), an incoming deep link must be stored in
  // pendingDeepLinkProvider instead of dispatched immediately. After the
  // user authenticates, the pending link is consumed and navigated.
  //
  // After Phase B: DeepLinkHandler.handleDeepLink(uri) stores the parsed
  // path in pendingDeepLinkProvider when session is not authenticated.
  // -----------------------------------------------------------------------
  group('INV-LINK-DEFERRED-1: deferred deep link storage', () {
    test(
      'stores invite deep link in pendingDeepLinkProvider when '
      'unauthenticated',
      skip: true,
      () {
        // Phase B:
        // final container = ProviderContainer();
        // addTearDown(container.dispose);
        //
        // // Simulate unauthenticated session.
        // // (override sessionStoreProvider with unauthenticated state)
        //
        // final handler = DeepLinkHandler(
        //   router: _fakeRouter(),
        //   ref: container,
        // );
        //
        // handler.handleDeepLink(
        //   Uri.parse('https://app.slock.ai/invite/token-1'),
        // );
        //
        // expect(
        //   container.read(pendingDeepLinkProvider),
        //   '/invite/token-1',
        // );
      },
    );

    test(
      'stores conversation deep link in pendingDeepLinkProvider when '
      'session is unknown',
      skip: true,
      () {
        // Phase B:
        // final container = ProviderContainer();
        // addTearDown(container.dispose);
        //
        // // Session status = AuthStatus.unknown (cold start).
        //
        // final handler = DeepLinkHandler(
        //   router: _fakeRouter(),
        //   ref: container,
        // );
        //
        // handler.handleDeepLink(
        //   Uri.parse('slock://servers/s1/channels/c1?messageId=m1'),
        // );
        //
        // expect(
        //   container.read(pendingDeepLinkProvider),
        //   '/servers/s1/channels/c1?messageId=m1',
        // );
      },
    );

    test(
      'pending deep link is consumed (set to null) after dispatch',
      skip: true,
      () {
        // Phase B:
        // final container = ProviderContainer();
        // addTearDown(container.dispose);
        //
        // // Pre-seed a pending deep link.
        // container.read(pendingDeepLinkProvider.notifier).state =
        //     '/invite/token-1';
        //
        // // Simulate authentication completing.
        // // (set session to authenticated, trigger router redirect)
        //
        // // Pending link should be cleared after consumption.
        // expect(container.read(pendingDeepLinkProvider), isNull);
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-LINK-DISPATCH-1: Deep link dispatch
  //
  // When the app IS authenticated and a deep link arrives, the handler
  // must call GoRouter.go() (for invite links) or GoRouter.push() (for
  // conversation/notification links) with the correct path. The dispatch
  // must also work for deferred links consumed after login.
  //
  // After Phase B: DeepLinkHandler dispatches to GoRouter with the
  // correct method and path for each link type.
  // -----------------------------------------------------------------------
  group('INV-LINK-DISPATCH-1: deep link dispatch', () {
    test(
      'dispatches invite deep link via GoRouter.go() when authenticated',
      skip: true,
      () {
        // Phase B:
        // final navigatedPaths = <String>[];
        // final router = _FakeGoRouter(onGo: navigatedPaths.add);
        // final container = ProviderContainer();
        // addTearDown(container.dispose);
        //
        // // Simulate authenticated session.
        //
        // final handler = DeepLinkHandler(
        //   router: router,
        //   ref: container,
        // );
        //
        // handler.handleDeepLink(
        //   Uri.parse('https://app.slock.ai/invite/abc123'),
        // );
        //
        // expect(navigatedPaths, ['/invite/abc123']);
      },
    );

    test(
      'dispatches conversation deep link via GoRouter.push() when '
      'authenticated',
      skip: true,
      () {
        // Phase B:
        // final pushedPaths = <String>[];
        // final router = _FakeGoRouter(onPush: pushedPaths.add);
        // final container = ProviderContainer();
        // addTearDown(container.dispose);
        //
        // // Simulate authenticated session.
        //
        // final handler = DeepLinkHandler(
        //   router: router,
        //   ref: container,
        // );
        //
        // handler.handleDeepLink(
        //   Uri.parse('slock://servers/s1/channels/c1?messageId=m1'),
        // );
        //
        // expect(
        //   pushedPaths,
        //   ['/servers/s1/channels/c1?messageId=m1'],
        // );
      },
    );

    test(
      'dispatches notification deep link (thread reply) via GoRouter.push()',
      skip: true,
      () {
        // Phase B:
        // final pushedPaths = <String>[];
        // final router = _FakeGoRouter(onPush: pushedPaths.add);
        // final container = ProviderContainer();
        // addTearDown(container.dispose);
        //
        // // Simulate authenticated session.
        //
        // final handler = DeepLinkHandler(
        //   router: router,
        //   ref: container,
        // );
        //
        // handler.handleDeepLink(
        //   Uri.parse('slock://servers/s1/threads/t1/replies'),
        // );
        //
        // expect(pushedPaths, ['/servers/s1/threads/t1/replies']);
      },
    );

    test(
      'does not dispatch when session is unauthenticated (stores instead)',
      skip: true,
      () {
        // Phase B:
        // final navigatedPaths = <String>[];
        // final router = _FakeGoRouter(
        //   onGo: navigatedPaths.add,
        //   onPush: navigatedPaths.add,
        // );
        // final container = ProviderContainer();
        // addTearDown(container.dispose);
        //
        // // Simulate unauthenticated session.
        //
        // final handler = DeepLinkHandler(
        //   router: router,
        //   ref: container,
        // );
        //
        // handler.handleDeepLink(
        //   Uri.parse('slock://servers/s1/channels/c1'),
        // );
        //
        // // No navigation should occur.
        // expect(navigatedPaths, isEmpty);
        // // Link should be stored instead.
        // expect(
        //   container.read(pendingDeepLinkProvider),
        //   '/servers/s1/channels/c1',
        // );
      },
    );
  });
}
