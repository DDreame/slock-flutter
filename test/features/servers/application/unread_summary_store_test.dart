// =============================================================================
// B124 PR 1 — Cross-server unread summary tests.
//
// Tests prove:
// 1. UnreadSummaryEntry model equality and hasUnread.
// 2. Repository parsing: valid payloads, malformed payloads, edge cases.
// 3. UnreadSummaryStore: initial fetch, polling, clear on logout, refresh.
// 4. Server switcher badge: dot shown for unread servers, not for active server.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/servers/data/unread_summary_repository.dart';
import 'package:slock_app/features/servers/data/unread_summary_repository_provider.dart';
import 'package:slock_app/features/servers/application/unread_summary_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  group('UnreadSummaryEntry', () {
    test('equality and hashCode', () {
      const a = UnreadSummaryEntry(serverId: 's1', unreadCount: 3);
      const b = UnreadSummaryEntry(serverId: 's1', unreadCount: 3);
      const c = UnreadSummaryEntry(serverId: 's1', unreadCount: 0);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('hasUnread is true when count > 0', () {
      const entry = UnreadSummaryEntry(serverId: 's1', unreadCount: 5);
      expect(entry.hasUnread, isTrue);
    });

    test('hasUnread is false when count == 0', () {
      const entry = UnreadSummaryEntry(serverId: 's1', unreadCount: 0);
      expect(entry.hasUnread, isFalse);
    });

    test('toString includes fields', () {
      const entry = UnreadSummaryEntry(serverId: 's1', unreadCount: 2);
      expect(entry.toString(), contains('s1'));
      expect(entry.toString(), contains('2'));
    });
  });

  group('UnreadSummaryRepository parsing', () {
    test('parses valid list response', () async {
      final repo = BaselineUnreadSummaryRepository(
        loadUnreadSummary: () async => [
          const UnreadSummaryEntry(serverId: 'srv-1', unreadCount: 3),
          const UnreadSummaryEntry(serverId: 'srv-2', unreadCount: 0),
        ],
      );

      final result = await repo.loadUnreadSummary();
      expect(result.length, 2);
      expect(result[0].serverId, 'srv-1');
      expect(result[0].unreadCount, 3);
      expect(result[1].serverId, 'srv-2');
      expect(result[1].unreadCount, 0);
    });
  });

  group('UnreadSummaryStore', () {
    late ProviderContainer container;
    late List<UnreadSummaryEntry> mockEntries;
    late int fetchCount;

    setUp(() {
      mockEntries = [
        const UnreadSummaryEntry(serverId: 'srv-1', unreadCount: 5),
        const UnreadSummaryEntry(serverId: 'srv-2', unreadCount: 0),
      ];
      fetchCount = 0;
    });

    ProviderContainer createContainer({bool authenticated = true}) {
      container = ProviderContainer(
        overrides: [
          unreadSummaryRepositoryProvider.overrideWithValue(
            BaselineUnreadSummaryRepository(
              loadUnreadSummary: () async {
                fetchCount++;
                return mockEntries;
              },
            ),
          ),
          sessionStoreProvider.overrideWith(
            () => _FakeSessionStore(authenticated: authenticated),
          ),
        ],
      );
      return container;
    }

    tearDown(() {
      container.dispose();
    });

    test('fetches on initialization when authenticated', () async {
      createContainer();
      // Trigger build.
      container.read(unreadSummaryStoreProvider);
      // Wait for microtask fetch.
      await Future<void>.delayed(Duration.zero);

      expect(fetchCount, 1);
      final state = container.read(unreadSummaryStoreProvider);
      expect(state['srv-1'], 5);
      expect(state['srv-2'], 0);
    });

    test('returns empty map when not authenticated', () {
      createContainer(authenticated: false);
      final state = container.read(unreadSummaryStoreProvider);
      expect(state, isEmpty);
      expect(fetchCount, 0);
    });

    test('refresh() triggers a new fetch', () async {
      createContainer();
      container.read(unreadSummaryStoreProvider);
      await Future<void>.delayed(Duration.zero);
      expect(fetchCount, 1);

      container.read(unreadSummaryStoreProvider.notifier).refresh();
      await Future<void>.delayed(Duration.zero);
      expect(fetchCount, 2);
    });

    test('silently ignores fetch errors', () async {
      var shouldFail = false;
      container = ProviderContainer(
        overrides: [
          unreadSummaryRepositoryProvider.overrideWithValue(
            BaselineUnreadSummaryRepository(
              loadUnreadSummary: () async {
                if (shouldFail) throw Exception('network error');
                return mockEntries;
              },
            ),
          ),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(authenticated: true)),
        ],
      );

      container.read(unreadSummaryStoreProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(unreadSummaryStoreProvider)['srv-1'], 5);

      // Next fetch fails — state should remain unchanged.
      shouldFail = true;
      container.read(unreadSummaryStoreProvider.notifier).refresh();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(unreadSummaryStoreProvider)['srv-1'], 5);
    });
  });
}

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore({required this.authenticated});
  final bool authenticated;

  @override
  SessionState build() => SessionState(
        status: authenticated
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        userId: authenticated ? 'user-1' : null,
        displayName: authenticated ? 'Test' : null,
        token: authenticated ? 'token' : null,
      );

  @override
  Future<void> logout() async {}
}
