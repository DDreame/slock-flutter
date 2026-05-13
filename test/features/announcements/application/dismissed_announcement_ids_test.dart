import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/features/announcements/application/dismissed_announcement_ids.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('DismissedAnnouncementIds', () {
    test('starts empty for a new server', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('srv-1')),
        ],
      );
      addTearDown(container.dispose);

      final dismissed = container.read(dismissedAnnouncementIdsProvider);
      expect(dismissed, isEmpty);
    });

    test('dismiss persists and is readable', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('srv-1')),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(dismissedAnnouncementIdsProvider.notifier)
          .dismiss('ann-1');

      final dismissed = container.read(dismissedAnnouncementIdsProvider);
      expect(dismissed, contains('ann-1'));
      expect(
        container
            .read(dismissedAnnouncementIdsProvider.notifier)
            .isDismissed('ann-1'),
        isTrue,
      );
    });

    test('loads persisted dismissed IDs from SharedPreferences', () async {
      await prefs.setStringList(
        'dismissed_announcements_srv-2',
        ['x1', 'x2'],
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('srv-2')),
        ],
      );
      addTearDown(container.dispose);

      final dismissed = container.read(dismissedAnnouncementIdsProvider);
      expect(dismissed, containsAll(['x1', 'x2']));
    });

    test(
        'server switch rebuilds with correct server dismissed set '
        '(INV-ANNOUNCE-3)', () async {
      // Pre-populate dismissed IDs for two servers.
      await prefs.setStringList(
        'dismissed_announcements_srv-A',
        ['a1', 'a2'],
      );
      await prefs.setStringList(
        'dismissed_announcements_srv-B',
        ['b1'],
      );

      // Start with server A.
      final serverOverride = StateProvider<ServerScopeId?>(
        (ref) => const ServerScopeId('srv-A'),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activeServerScopeIdProvider.overrideWith(
            (ref) => ref.watch(serverOverride),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Verify server A dismissed set.
      final dismissedA = container.read(dismissedAnnouncementIdsProvider);
      expect(dismissedA, containsAll(['a1', 'a2']));
      expect(dismissedA, isNot(contains('b1')));

      // Switch to server B.
      container.read(serverOverride.notifier).state =
          const ServerScopeId('srv-B');

      // The dismissed set should rebuild with server B's data.
      final dismissedB = container.read(dismissedAnnouncementIdsProvider);
      expect(dismissedB, contains('b1'));
      expect(dismissedB, isNot(contains('a1')));
      expect(dismissedB, isNot(contains('a2')));
    });

    test('dismissed IDs are isolated per server', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('srv-1')),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(dismissedAnnouncementIdsProvider.notifier)
          .dismiss('ann-1');

      // Verify persisted under server-scoped key.
      final stored = prefs.getStringList('dismissed_announcements_srv-1');
      expect(stored, contains('ann-1'));

      // Different server key should be empty.
      final otherStored = prefs.getStringList('dismissed_announcements_srv-2');
      expect(otherStored, isNull);
    });
  });
}
