// =============================================================================
// #845 — P2 Deep Link Duplicate Push + ConversationDetail Server Scope
//
// Load-bearing tests:
// 1. DeepLinkHandler._dispatch debounce: same path dispatched rapidly → only
//    first push fires; removing debounce guard → both pushes fire (test RED).
// 2. ConversationDetailStore._isCurrentRequest server scope: load starts on
//    server A, active server switches to B → response discarded; removing
//    server scope check → stale data written (test RED).
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/core/deep_link/deep_link_handler.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../support/support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // Group 1: Deep link duplicate push prevention (debounce guard)
  // ===========================================================================
  group('#845 — Deep link debounce', () {
    test('rapid duplicate dispatch pushes only once', () {
      final pushLog = <String>[];
      final router = _FakeGoRouter(pushLog: pushLog);
      final container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith(() => _AuthenticatedSessionStore()),
      ]);

      final handler = DeepLinkHandler(router: router, ref: container);

      // Dispatch the same path twice rapidly (< 500ms apart).
      handler.handleDeepLink(
          Uri.parse('https://app.slock.ai/servers/s1/channels/c1'));
      handler.handleDeepLink(
          Uri.parse('https://app.slock.ai/servers/s1/channels/c1'));

      // Only one push should have fired.
      expect(pushLog.length, 1);
      expect(pushLog.first, '/servers/s1/channels/c1');

      container.dispose();
    });

    test('different paths dispatch normally', () {
      final pushLog = <String>[];
      final router = _FakeGoRouter(pushLog: pushLog);
      final container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith(() => _AuthenticatedSessionStore()),
      ]);

      final handler = DeepLinkHandler(router: router, ref: container);

      handler.handleDeepLink(
          Uri.parse('https://app.slock.ai/servers/s1/channels/c1'));
      handler.handleDeepLink(
          Uri.parse('https://app.slock.ai/servers/s1/channels/c2'));

      // Both should push (different paths).
      expect(pushLog.length, 2);

      container.dispose();
    });

    test('same path dispatches after debounce window expires', () async {
      final pushLog = <String>[];
      final router = _FakeGoRouter(pushLog: pushLog);
      final container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith(() => _AuthenticatedSessionStore()),
      ]);

      final handler = DeepLinkHandler(router: router, ref: container);

      handler.handleDeepLink(
          Uri.parse('https://app.slock.ai/servers/s1/channels/c1'));
      expect(pushLog.length, 1);

      // Wait past the debounce window (500ms).
      await Future<void>.delayed(const Duration(milliseconds: 600));

      handler.handleDeepLink(
          Uri.parse('https://app.slock.ai/servers/s1/channels/c1'));
      expect(pushLog.length, 2);

      container.dispose();
    });
  });

  // ===========================================================================
  // Group 2: ConversationDetail server scope check
  // ===========================================================================
  group('#845 — ConversationDetail server scope', () {
    test('load discards response when active server changes during request',
        () async {
      final loadCompleter = Completer<ConversationDetailSnapshot>();
      final repo = _DelayedConversationRepo(loadCompleter);

      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'ch-1',
        ),
      );

      // Mutable holder so we can change the value returned by the override
      // between the load start and the response callback.
      ServerScopeId? activeServerId = const ServerScopeId('server-1');

      final fixture = RuntimeAppFixture(
        extraOverrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          activeServerScopeIdProvider.overrideWith(
            (ref) => activeServerId,
          ),
        ],
      );

      await fixture.boot();

      final sub =
          fixture.container.listen(conversationDetailStoreProvider, (_, __) {});
      final store =
          fixture.container.read(conversationDetailStoreProvider.notifier);

      // Trigger load — this will await the delayed repo.
      unawaited(store.load());

      // Simulate server switch: active server → server-2.
      // The override closure captures `activeServerId` by reference, so
      // changing it here means the next ref.read(activeServerScopeIdProvider)
      // inside _isCurrentRequest will return 'server-2'.
      activeServerId = const ServerScopeId('server-2');
      // Invalidate so the provider re-evaluates on next read.
      fixture.container.invalidate(activeServerScopeIdProvider);

      // Resolve the load with server-1 data.
      loadCompleter.complete(ConversationDetailSnapshot(
        target: target,
        title: 'Server 1 Channel',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ));

      // Give the async code a chance to complete.
      await Future<void>.delayed(Duration.zero);

      // The response should be discarded — title must NOT be updated.
      expect(store.state.title, isNot('Server 1 Channel'),
          reason: 'load must discard response when active server has changed');
      expect(store.state.status, isNot(ConversationDetailStatus.success));

      sub.close();
      fixture.dispose();
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

/// Fake GoRouter that logs push/go calls.
class _FakeGoRouter implements GoRouter {
  _FakeGoRouter({required this.pushLog});

  final List<String> pushLog;

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) async {
    pushLog.add(location);
    return null;
  }

  @override
  void go(String location, {Object? extra}) {
    pushLog.add(location);
  }

  @override
  GoRouteInformationProvider get routeInformationProvider => _fakeInfoProvider;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _fakeInfoProvider = GoRouteInformationProvider(
  initialLocation: '/home',
  initialExtra: null,
);

/// SessionStore that reports authenticated.
class _AuthenticatedSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(status: AuthStatus.authenticated);
}

/// ConversationRepository that delays loadConversation until a completer fires.
class _DelayedConversationRepo implements ConversationRepository {
  _DelayedConversationRepo(this._completer);

  final Completer<ConversationDetailSnapshot> _completer;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) =>
      _completer.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
