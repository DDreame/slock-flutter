// =============================================================================
// Scan #46 PR D — Web Gap load-bearing tests
//
// These tests prove:
// - PATCH-1: updateChannel sends description + isPrivate when provided
// - PATCH-2: updateChannel sends only non-null fields (partial update)
// - EVT-1: announcement:updated event routed through DomainRuntimeEventRouter
//          updates announcement in store
// - EVT-2: announcement:deleted event routed through DomainRuntimeEventRouter
//          removes announcement from store
//
// Reverting the production fix (removing description/isPrivate from PATCH body
// or removing event handlers) causes the corresponding test to go RED.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/announcements/application/announcement_store.dart';
import 'package:slock_app/features/announcements/application/dismissed_announcement_ids.dart';
import 'package:slock_app/features/announcements/data/announcement.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';

import '../support/runtime_app_fixture.dart';

void main() {
  // ===========================================================================
  // PATCH-1: updateChannel sends description + isPrivate in body
  // ===========================================================================
  group('Scan #46 PATCH — updateChannel sends all fields', () {
    test('includes description and isPrivate when provided', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('PATCH', '/channels/ch-1'): null,
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(channelManagementRepositoryProvider);
      await repository.updateChannel(
        const ServerScopeId('server-1'),
        channelId: 'ch-1',
        name: 'updated-name',
        description: 'A new description',
        isPrivate: true,
      );

      expect(appDioClient.requests, hasLength(1));
      final request = appDioClient.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/channels/ch-1');
      expect(
        request.data,
        {
          'name': 'updated-name',
          'description': 'A new description',
          'isPrivate': true,
        },
        reason: 'Scan #46: updateChannel PATCH must include description '
            'and isPrivate. Removing them from body → RED.',
      );
    });

    // =========================================================================
    // PATCH-2: Partial update — only non-null fields sent
    // =========================================================================
    test('sends only description when name and isPrivate are null', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('PATCH', '/channels/ch-2'): null,
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(channelManagementRepositoryProvider);
      await repository.updateChannel(
        const ServerScopeId('server-1'),
        channelId: 'ch-2',
        description: 'Only description update',
      );

      expect(appDioClient.requests.single.data, {
        'description': 'Only description update',
      });
    });

    test('sends only isPrivate when name and description are null', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('PATCH', '/channels/ch-3'): null,
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(channelManagementRepositoryProvider);
      await repository.updateChannel(
        const ServerScopeId('server-1'),
        channelId: 'ch-3',
        isPrivate: false,
      );

      expect(appDioClient.requests.single.data, {'isPrivate': false});
    });
  });

  // ===========================================================================
  // EVT-1: announcement:updated routed through DomainRuntimeEventRouter
  // ===========================================================================
  group('Scan #46 Router — announcement:updated', () {
    test('routes announcement:updated event to store (updates in-place)',
        () async {
      final fixture = RuntimeAppFixture(
        extraOverrides: [
          dismissedAnnouncementIdsProvider.overrideWith(
            () => _FakeDismissedIds(),
          ),
        ],
      );
      final container = await fixture.boot();
      addTearDown(fixture.dispose);

      // Seed an announcement in the store.
      container.read(announcementStoreProvider.notifier).addAnnouncement(
            const Announcement(
              id: 'ann-1',
              title: 'Original Title',
              body: 'Original body',
            ),
          );

      expect(
        container.read(announcementStoreProvider).announcements.first.title,
        'Original Title',
      );

      // Emit announcement:updated through the router ingress.
      fixture.ingress.accept(RealtimeEventEnvelope(
        eventType: 'announcement:updated',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: {
          'id': 'ann-1',
          'title': 'Updated Title',
          'body': 'Updated body',
        },
      ));

      // Broadcast stream delivers in next microtask.
      await Future<void>.delayed(Duration.zero);

      final announcements =
          container.read(announcementStoreProvider).announcements;
      expect(announcements, hasLength(1));
      expect(
        announcements.first.title,
        'Updated Title',
        reason: 'Scan #46: announcement:updated must route through event '
            'router and update store in-place. '
            'Removing router case → RED.',
      );
      expect(announcements.first.body, 'Updated body');
    });

    test('no-ops when announcement not in store', () async {
      final fixture = RuntimeAppFixture(
        extraOverrides: [
          dismissedAnnouncementIdsProvider.overrideWith(
            () => _FakeDismissedIds(),
          ),
        ],
      );
      final container = await fixture.boot();
      addTearDown(fixture.dispose);

      // Seed a different announcement.
      container.read(announcementStoreProvider.notifier).addAnnouncement(
            const Announcement(id: 'ann-1', title: 'Keep this'),
          );

      // Update a non-existent announcement through the router.
      fixture.ingress.accept(RealtimeEventEnvelope(
        eventType: 'announcement:updated',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: {'id': 'ann-999', 'title': 'Ghost'},
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(announcementStoreProvider);
      expect(state.announcements, hasLength(1));
      expect(state.announcements.first.id, 'ann-1');
    });
  });

  // ===========================================================================
  // EVT-2: announcement:deleted routed through DomainRuntimeEventRouter
  // ===========================================================================
  group('Scan #46 Router — announcement:deleted', () {
    test('routes announcement:deleted event to store (removes by ID)',
        () async {
      final fixture = RuntimeAppFixture(
        extraOverrides: [
          dismissedAnnouncementIdsProvider.overrideWith(
            () => _FakeDismissedIds(),
          ),
        ],
      );
      final container = await fixture.boot();
      addTearDown(fixture.dispose);

      // Seed two announcements.
      final store = container.read(announcementStoreProvider.notifier);
      store.addAnnouncement(const Announcement(id: 'ann-1', title: 'First'));
      store.addAnnouncement(const Announcement(id: 'ann-2', title: 'Second'));

      expect(
        container.read(announcementStoreProvider).announcements,
        hasLength(2),
      );

      // Emit announcement:deleted through the router ingress.
      fixture.ingress.accept(RealtimeEventEnvelope(
        eventType: 'announcement:deleted',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: {'id': 'ann-1'},
      ));

      await Future<void>.delayed(Duration.zero);

      final remaining = container.read(announcementStoreProvider).announcements;
      expect(
        remaining,
        hasLength(1),
        reason: 'Scan #46: announcement:deleted must route through event '
            'router and remove from store. '
            'Removing router case → RED.',
      );
      expect(remaining.first.id, 'ann-2');
    });

    test('no-ops when announcement not in store', () async {
      final fixture = RuntimeAppFixture(
        extraOverrides: [
          dismissedAnnouncementIdsProvider.overrideWith(
            () => _FakeDismissedIds(),
          ),
        ],
      );
      final container = await fixture.boot();
      addTearDown(fixture.dispose);

      container.read(announcementStoreProvider.notifier).addAnnouncement(
            const Announcement(id: 'ann-1', title: 'Keep this'),
          );

      // Delete a non-existent announcement through the router.
      fixture.ingress.accept(RealtimeEventEnvelope(
        eventType: 'announcement:deleted',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: {'id': 'ann-999'},
      ));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(announcementStoreProvider);
      expect(state.announcements, hasLength(1));
    });
  });
}

// =============================================================================
// Helpers
// =============================================================================

class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({
    Map<(String, String), Object?> responses = const {},
  })  : _responses = responses,
        super(Dio());

  final Map<(String, String), Object?> _responses;
  final List<_CapturedRequest> requests = [];

  @override
  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    final headers = Map<String, Object?>.from(options?.headers ?? const {});
    requests.add(
      _CapturedRequest(
        method: method,
        path: path,
        data: data,
        headers: headers,
      ),
    );

    final key = (method, path);
    if (!_responses.containsKey(key)) {
      throw StateError('Missing fake response for $key');
    }

    return Response<T>(
      requestOptions: RequestOptions(
        path: path,
        method: method,
        headers: headers,
      ),
      data: _responses[key] as T,
    );
  }
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.data,
    required this.headers,
  });

  final String method;
  final String path;
  final Object? data;
  final Map<String, Object?> headers;
}

class _FakeDismissedIds extends DismissedAnnouncementIds {
  @override
  Set<String> build() => const {};
}
