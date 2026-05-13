import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/features/announcements/application/announcement_store.dart';
import 'package:slock_app/features/announcements/application/dismissed_announcement_ids.dart';
import 'package:slock_app/features/announcements/data/announcement.dart';
import 'package:slock_app/features/announcements/data/announcement_repository.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer({
    ServerScopeId? serverId,
    List<Announcement> apiAnnouncements = const [],
  }) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeServerScopeIdProvider.overrideWithValue(serverId),
        announcementRepositoryProvider.overrideWithValue(
          _FakeAnnouncementRepository(apiAnnouncements),
        ),
      ],
    );
  }

  group('AnnouncementStore load (INV-ANNOUNCE-1)', () {
    test('load() transitions to success with announcements', () async {
      final container = createContainer(
        serverId: const ServerScopeId('srv-1'),
        apiAnnouncements: [
          const Announcement(id: 'a1', title: 'Hello'),
        ],
      );
      addTearDown(container.dispose);

      // Initial state before any load.
      final initial = container.read(announcementStoreProvider);
      expect(initial.status, AnnouncementStatus.initial);

      // Explicit load (mirrors banner calling ensureLoaded).
      await container.read(announcementStoreProvider.notifier).load();

      final loaded = container.read(announcementStoreProvider);
      expect(loaded.status, AnnouncementStatus.success);
      expect(loaded.announcements, hasLength(1));
      expect(loaded.announcements.first.id, 'a1');

      // ensureLoaded() is a no-op once already loaded.
      await container.read(announcementStoreProvider.notifier).ensureLoaded();
      final afterEnsure = container.read(announcementStoreProvider);
      expect(afterEnsure.status, AnnouncementStatus.success);
      expect(afterEnsure.announcements, hasLength(1));
    });

    test('load() with null server returns empty success', () async {
      final container = createContainer(
        serverId: null,
        apiAnnouncements: [
          const Announcement(id: 'a1', title: 'Ignored'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(announcementStoreProvider.notifier).load();

      final loaded = container.read(announcementStoreProvider);
      expect(loaded.status, AnnouncementStatus.success);
      expect(loaded.announcements, isEmpty);
    });

    test('load() filters out dismissed announcements', () async {
      // Pre-populate dismissed IDs for srv-1.
      await prefs.setStringList('dismissed_announcements_srv-1', ['a2']);

      final container = createContainer(
        serverId: const ServerScopeId('srv-1'),
        apiAnnouncements: [
          const Announcement(id: 'a1', title: 'Visible'),
          const Announcement(id: 'a2', title: 'Dismissed'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(announcementStoreProvider.notifier).load();

      final loaded = container.read(announcementStoreProvider);
      expect(loaded.status, AnnouncementStatus.success);
      expect(loaded.announcements, hasLength(1));
      expect(loaded.announcements.first.id, 'a1');
    });
  });

  group('server switch rebuilds store (INV-ANNOUNCE-1 + INV-ANNOUNCE-3)', () {
    test('switching servers resets state to initial and reloads', () async {
      const serverA = ServerScopeId('srv-A');
      const serverB = ServerScopeId('srv-B');

      final fakeRepo = _ServerAwareFakeRepository({
        'srv-A': [const Announcement(id: 'a1', title: 'Server A')],
        'srv-B': [const Announcement(id: 'b1', title: 'Server B')],
      });

      final serverOverride = StateProvider<ServerScopeId?>(
        (ref) => serverA,
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activeServerScopeIdProvider.overrideWith(
            (ref) => ref.watch(serverOverride),
          ),
          announcementRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // Keep a listener alive so rebuilds propagate reactively.
      final sub = container.listen(announcementStoreProvider, (_, __) {});

      // Load for server A.
      await container.read(announcementStoreProvider.notifier).load();

      final stateA = container.read(announcementStoreProvider);
      expect(stateA.status, AnnouncementStatus.success);
      expect(stateA.announcements, hasLength(1));
      expect(stateA.announcements.first.id, 'a1');

      // Switch to server B — triggers rebuild via ref.watch.
      container.read(serverOverride.notifier).state = serverB;

      // After rebuild, state resets to initial.
      final stateAfterSwitch = container.read(announcementStoreProvider);
      expect(stateAfterSwitch.status, AnnouncementStatus.initial);

      // Explicit load for server B.
      await container.read(announcementStoreProvider.notifier).load();

      final stateB = container.read(announcementStoreProvider);
      expect(stateB.status, AnnouncementStatus.success);
      expect(stateB.announcements, hasLength(1));
      expect(stateB.announcements.first.id, 'b1');

      sub.close();
    });
  });

  group('addAnnouncement (INV-ANNOUNCE-4)', () {
    test('promotes status to success from initial', () {
      final container = createContainer(
        serverId: const ServerScopeId('srv-1'),
      );
      addTearDown(container.dispose);

      // State starts at initial (no auto-load).
      final initial = container.read(announcementStoreProvider);
      expect(initial.status, AnnouncementStatus.initial);

      container.read(announcementStoreProvider.notifier).addAnnouncement(
            const Announcement(id: 'ws-1', title: 'From WebSocket'),
          );

      final updated = container.read(announcementStoreProvider);
      expect(updated.status, AnnouncementStatus.success);
      expect(updated.announcements, hasLength(1));
      expect(updated.announcements.first.id, 'ws-1');
    });

    test('skips dismissed announcement', () async {
      await prefs.setStringList('dismissed_announcements_srv-1', ['ws-2']);

      final container = createContainer(
        serverId: const ServerScopeId('srv-1'),
      );
      addTearDown(container.dispose);

      container.read(announcementStoreProvider.notifier).addAnnouncement(
            const Announcement(id: 'ws-2', title: 'Already Dismissed'),
          );

      final updated = container.read(announcementStoreProvider);
      expect(updated.announcements, isEmpty);
    });

    test('deduplicates existing announcement', () async {
      final container = createContainer(
        serverId: const ServerScopeId('srv-1'),
        apiAnnouncements: [
          const Announcement(id: 'a1', title: 'Existing'),
        ],
      );
      addTearDown(container.dispose);

      // Explicit load.
      await container.read(announcementStoreProvider.notifier).load();

      container.read(announcementStoreProvider.notifier).addAnnouncement(
            const Announcement(id: 'a1', title: 'Duplicate'),
          );

      final updated = container.read(announcementStoreProvider);
      expect(updated.announcements, hasLength(1));
    });
  });

  group('dismiss (INV-ANNOUNCE-2)', () {
    test('optimistically removes from list and persists', () async {
      final container = createContainer(
        serverId: const ServerScopeId('srv-1'),
        apiAnnouncements: [
          const Announcement(id: 'a1', title: 'To Dismiss'),
          const Announcement(id: 'a2', title: 'Keep'),
        ],
      );
      addTearDown(container.dispose);

      // Explicit load.
      await container.read(announcementStoreProvider.notifier).load();

      await container.read(announcementStoreProvider.notifier).dismiss('a1');

      final updated = container.read(announcementStoreProvider);
      expect(updated.announcements, hasLength(1));
      expect(updated.announcements.first.id, 'a2');

      // Verify persisted.
      final dismissed = container.read(dismissedAnnouncementIdsProvider);
      expect(dismissed, contains('a1'));
    });
  });
}

class _FakeAnnouncementRepository implements AnnouncementRepository {
  _FakeAnnouncementRepository(this._announcements);

  final List<Announcement> _announcements;
  final List<String> dismissedIds = [];

  @override
  Future<List<Announcement>> getActive(ServerScopeId serverId) async {
    return _announcements;
  }

  @override
  Future<void> dismiss(
    ServerScopeId serverId, {
    required String announcementId,
  }) async {
    dismissedIds.add(announcementId);
  }
}

/// A fake repository that returns different announcements per server.
class _ServerAwareFakeRepository implements AnnouncementRepository {
  _ServerAwareFakeRepository(this._perServer);

  final Map<String, List<Announcement>> _perServer;

  @override
  Future<List<Announcement>> getActive(ServerScopeId serverId) async {
    return _perServer[serverId.value] ?? const [];
  }

  @override
  Future<void> dismiss(
    ServerScopeId serverId, {
    required String announcementId,
  }) async {}
}
