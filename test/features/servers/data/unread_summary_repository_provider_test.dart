// =============================================================================
// B124 PR 1 — UnreadSummaryRepository provider parsing tests.
//
// Verifies that the parsing logic correctly handles:
// 1. Valid list response with multiple entries.
// 2. Entries with missing/invalid serverId → skipped.
// 3. Entries with missing/invalid unreadCount → skipped.
// 4. Non-list payload → throws SerializationFailure.
// 5. Float unreadCount → floored.
// 6. Negative unreadCount → clamped to 0.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/data/unread_summary_repository.dart';
import 'package:slock_app/features/servers/data/unread_summary_repository_provider.dart';

import '../../../support/fakes/fake_app_dio_client.dart';

void main() {
  group('UnreadSummaryRepository parsing via provider', () {
    late ProviderContainer container;

    /// Creates a container with a fake Dio that returns [responseData].
    ProviderContainer createWithResponse(Object? responseData) {
      final fakeClient = FakeAppDioClient(
        responses: {('GET', '/servers/unread-summary'): responseData},
      );
      container = ProviderContainer(
        overrides: [
          appDioClientProvider.overrideWithValue(fakeClient),
        ],
      );
      return container;
    }

    tearDown(() {
      container.dispose();
    });

    test('parses valid list with multiple entries', () async {
      createWithResponse([
        {'serverId': 'srv-1', 'unreadCount': 3},
        {'serverId': 'srv-2', 'unreadCount': 0},
        {'serverId': 'srv-3', 'unreadCount': 42},
      ]);

      final repo = container.read(unreadSummaryRepositoryProvider);
      final result = await repo.loadUnreadSummary();

      expect(result.length, 3);
      expect(result[0],
          const UnreadSummaryEntry(serverId: 'srv-1', unreadCount: 3));
      expect(result[1],
          const UnreadSummaryEntry(serverId: 'srv-2', unreadCount: 0));
      expect(result[2],
          const UnreadSummaryEntry(serverId: 'srv-3', unreadCount: 42));
    });

    test('skips entries with missing serverId', () async {
      createWithResponse([
        {'unreadCount': 3},
        {'serverId': 'srv-2', 'unreadCount': 1},
      ]);

      final repo = container.read(unreadSummaryRepositoryProvider);
      final result = await repo.loadUnreadSummary();

      expect(result.length, 1);
      expect(result[0].serverId, 'srv-2');
    });

    test('skips entries with empty serverId', () async {
      createWithResponse([
        {'serverId': '', 'unreadCount': 3},
        {'serverId': 'srv-2', 'unreadCount': 1},
      ]);

      final repo = container.read(unreadSummaryRepositoryProvider);
      final result = await repo.loadUnreadSummary();

      expect(result.length, 1);
      expect(result[0].serverId, 'srv-2');
    });

    test('skips entries with non-string serverId', () async {
      createWithResponse([
        {'serverId': 123, 'unreadCount': 3},
        {'serverId': 'srv-2', 'unreadCount': 1},
      ]);

      final repo = container.read(unreadSummaryRepositoryProvider);
      final result = await repo.loadUnreadSummary();

      expect(result.length, 1);
      expect(result[0].serverId, 'srv-2');
    });

    test('skips entries with missing unreadCount', () async {
      createWithResponse([
        {'serverId': 'srv-1'},
        {'serverId': 'srv-2', 'unreadCount': 5},
      ]);

      final repo = container.read(unreadSummaryRepositoryProvider);
      final result = await repo.loadUnreadSummary();

      expect(result.length, 1);
      expect(result[0].serverId, 'srv-2');
    });

    test('skips entries with non-numeric unreadCount', () async {
      createWithResponse([
        {'serverId': 'srv-1', 'unreadCount': 'many'},
        {'serverId': 'srv-2', 'unreadCount': 5},
      ]);

      final repo = container.read(unreadSummaryRepositoryProvider);
      final result = await repo.loadUnreadSummary();

      expect(result.length, 1);
      expect(result[0].serverId, 'srv-2');
    });

    test('skips entries with NaN/Infinity unreadCount', () async {
      createWithResponse([
        {'serverId': 'srv-1', 'unreadCount': double.nan},
        {'serverId': 'srv-2', 'unreadCount': double.infinity},
        {'serverId': 'srv-3', 'unreadCount': 7},
      ]);

      final repo = container.read(unreadSummaryRepositoryProvider);
      final result = await repo.loadUnreadSummary();

      expect(result.length, 1);
      expect(result[0].serverId, 'srv-3');
    });

    test('floors float unreadCount', () async {
      createWithResponse([
        {'serverId': 'srv-1', 'unreadCount': 3.7},
      ]);

      final repo = container.read(unreadSummaryRepositoryProvider);
      final result = await repo.loadUnreadSummary();

      expect(result.length, 1);
      expect(result[0].unreadCount, 3);
    });

    test('clamps negative unreadCount to 0', () async {
      createWithResponse([
        {'serverId': 'srv-1', 'unreadCount': -5},
      ]);

      final repo = container.read(unreadSummaryRepositoryProvider);
      final result = await repo.loadUnreadSummary();

      expect(result.length, 1);
      expect(result[0].unreadCount, 0);
    });

    test('throws SerializationFailure for non-list payload', () async {
      createWithResponse({'error': 'not a list'});

      final repo = container.read(unreadSummaryRepositoryProvider);
      expect(
        () => repo.loadUnreadSummary(),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('returns empty list for empty array', () async {
      createWithResponse(<Object?>[]);

      final repo = container.read(unreadSummaryRepositoryProvider);
      final result = await repo.loadUnreadSummary();

      expect(result, isEmpty);
    });

    test('skips non-map entries in the array', () async {
      createWithResponse([
        'not a map',
        42,
        {'serverId': 'srv-1', 'unreadCount': 1},
      ]);

      final repo = container.read(unreadSummaryRepositoryProvider);
      final result = await repo.loadUnreadSummary();

      expect(result.length, 1);
      expect(result[0].serverId, 'srv-1');
    });
  });
}
