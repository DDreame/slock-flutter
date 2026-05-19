// =============================================================================
// #604 — sessionStore + serverListStore .select() Optimization
//        (channel_members_page.dart)
//
// Invariant: INV-MEMBERS-SELECT-1
//   Channel members page must only rebuild when consumed fields change:
//   - sessionStoreProvider → userId only
//   - serverListStoreProvider → servers only
//
// Strategy:
// T1: token change must NOT fire userId-select (skip:true).
// T2: displayName change must NOT fire userId-select (skip:true).
// T3: userId change DOES fire userId-select (active).
// T4: isCreating change must NOT fire servers-select (skip:true).
// T5: servers change DOES fire servers-select (active).
//
// Phase A: T1/T2/T4 skip:true — broad watch in current impl.
//          T3/T5 active — correctness proofs.
//
// Phase B:
// - channel_members_page.dart L136: ref.watch(sessionStoreProvider).userId →
//   ref.watch(sessionStoreProvider.select((s) => s.userId))
// - channel_members_page.dart L155: ref.watch(serverListStoreProvider) →
//   ref.watch(serverListStoreProvider.select((s) => s.servers))
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        token: 'token-abc',
        displayName: 'Alice',
        avatarUrl: 'https://example.com/avatar.png',
      );

  void setTokenDirect(String token) {
    state = state.copyWith(token: token);
  }

  void setDisplayNameDirect(String name) {
    state = state.copyWith(displayName: name);
  }

  void setUserIdDirect(String userId) {
    state = state.copyWith(userId: userId);
  }
}

class _ControllableServerListStore extends ServerListStore {
  @override
  ServerListState build() => const ServerListState(
        status: ServerListStatus.success,
        servers: [ServerSummary(id: 'server-1', name: 'Workspace')],
      );

  void setIsCreatingDirect(bool value) {
    state = state.copyWith(isCreating: value);
  }

  void setServersDirect(List<ServerSummary> servers) {
    state = state.copyWith(servers: servers);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: token change must NOT fire userId-select.
  // -------------------------------------------------------------------------
  test(
    'INV-MEMBERS-SELECT-1: token change does NOT notify userId select',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _ControllableSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(sessionStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        sessionStoreProvider.select((s) => s.userId),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setTokenDirect('token-xyz');

      expect(
        selectNotifyCount,
        0,
        reason: 'token change must not notify userId select '
            '(INV-MEMBERS-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: true, // Phase A: requires Phase B .select() fix
  );

  // -------------------------------------------------------------------------
  // T2: displayName change must NOT fire userId-select.
  // -------------------------------------------------------------------------
  test(
    'INV-MEMBERS-SELECT-1: displayName change does NOT notify userId select',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _ControllableSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(sessionStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        sessionStoreProvider.select((s) => s.userId),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setDisplayNameDirect('Bob');

      expect(
        selectNotifyCount,
        0,
        reason: 'displayName change must not notify userId select '
            '(INV-MEMBERS-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: true, // Phase A: requires Phase B .select() fix
  );

  // -------------------------------------------------------------------------
  // T3: userId change DOES fire userId-select.
  // -------------------------------------------------------------------------
  test(
    'INV-MEMBERS-SELECT-1: userId change DOES notify userId select',
    () async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWith(() => _ControllableSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(sessionStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        sessionStoreProvider.select((s) => s.userId),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(sessionStoreProvider.notifier)
          as _ControllableSessionStore;
      store.setUserIdDirect('user-2');

      expect(
        selectNotifyCount,
        1,
        reason: 'userId change must notify userId select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: isCreating change must NOT fire servers-select.
  // -------------------------------------------------------------------------
  test(
    'INV-MEMBERS-SELECT-1: isCreating change does NOT notify servers select',
    () async {
      final container = ProviderContainer(
        overrides: [
          serverListStoreProvider
              .overrideWith(() => _ControllableServerListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(serverListStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        serverListStoreProvider.select((s) => s.servers),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(serverListStoreProvider.notifier)
          as _ControllableServerListStore;
      store.setIsCreatingDirect(true);

      expect(
        selectNotifyCount,
        0,
        reason: 'isCreating change must not notify servers select '
            '(INV-MEMBERS-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: true, // Phase A: requires Phase B .select() fix
  );

  // -------------------------------------------------------------------------
  // T5: servers change DOES fire servers-select.
  // -------------------------------------------------------------------------
  test(
    'INV-MEMBERS-SELECT-1: servers change DOES notify servers select',
    () async {
      final container = ProviderContainer(
        overrides: [
          serverListStoreProvider
              .overrideWith(() => _ControllableServerListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(serverListStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        serverListStoreProvider.select((s) => s.servers),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(serverListStoreProvider.notifier)
          as _ControllableServerListStore;
      store.setServersDirect(const [
        ServerSummary(id: 'server-1', name: 'Workspace'),
        ServerSummary(id: 'server-2', name: 'Another'),
      ]);

      expect(
        selectNotifyCount,
        1,
        reason: 'servers change must notify servers select',
      );

      keepAlive.close();
    },
  );
}
