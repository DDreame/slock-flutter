import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_repository.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';

void main() {
  ProviderContainer createContainer({
    ServerScopeId? serverId,
    TranslationSettings apiSettings = const TranslationSettings(),
    bool failOnGet = false,
    bool failOnUpdate = false,
  }) {
    return ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        translationRepositoryProvider.overrideWithValue(
          _FakeTranslationRepository(
            settings: apiSettings,
            failOnGet: failOnGet,
            failOnUpdate: failOnUpdate,
          ),
        ),
      ],
    );
  }

  group('TranslationSettingsStore load', () {
    test('load() transitions to success with server settings', () async {
      const apiSettings = TranslationSettings(
        preferredLanguage: 'ja',
        mode: TranslationMode.auto,
      );
      final container = createContainer(
        serverId: const ServerScopeId('srv-1'),
        apiSettings: apiSettings,
      );
      addTearDown(container.dispose);

      // Initial state before load.
      final initial = container.read(translationSettingsStoreProvider);
      expect(initial.status, TranslationSettingsStatus.initial);

      // Explicit load.
      await container.read(translationSettingsStoreProvider.notifier).load();

      final state = container.read(translationSettingsStoreProvider);
      expect(state.status, TranslationSettingsStatus.success);
      expect(state.settings.preferredLanguage, 'ja');
      expect(state.settings.mode, TranslationMode.auto);
    });

    test('null server returns default success', () async {
      final container = createContainer(serverId: null);
      addTearDown(container.dispose);

      await container.read(translationSettingsStoreProvider.notifier).load();

      final state = container.read(translationSettingsStoreProvider);
      expect(state.status, TranslationSettingsStatus.success);
      expect(state.settings.preferredLanguage, 'en');
      expect(state.settings.mode, TranslationMode.off);
    });
  });

  group('TranslationSettingsStore.update', () {
    test('optimistically updates and persists via API', () async {
      const initial = TranslationSettings(
        preferredLanguage: 'en',
        mode: TranslationMode.off,
      );
      final container = createContainer(
        serverId: const ServerScopeId('srv-1'),
        apiSettings: initial,
      );
      addTearDown(container.dispose);

      // Explicit load.
      await container.read(translationSettingsStoreProvider.notifier).load();

      const updated = TranslationSettings(
        preferredLanguage: 'zh',
        mode: TranslationMode.auto,
      );
      await container
          .read(translationSettingsStoreProvider.notifier)
          .update(updated);

      final state = container.read(translationSettingsStoreProvider);
      expect(state.settings.preferredLanguage, 'zh');
      expect(state.settings.mode, TranslationMode.auto);
    });

    test(
        'update with null server surfaces failure and does not change settings',
        () async {
      final container = createContainer(serverId: null);
      addTearDown(container.dispose);

      await container.read(translationSettingsStoreProvider.notifier).load();

      final before = container.read(translationSettingsStoreProvider);
      expect(before.status, TranslationSettingsStatus.success);
      expect(before.settings.preferredLanguage, 'en');

      const attempted = TranslationSettings(
        preferredLanguage: 'fr',
        mode: TranslationMode.auto,
      );
      await container
          .read(translationSettingsStoreProvider.notifier)
          .update(attempted);

      final after = container.read(translationSettingsStoreProvider);
      // Settings unchanged — update rejected.
      expect(after.settings.preferredLanguage, 'en');
      expect(after.settings.mode, TranslationMode.off);
      // Failure surfaced.
      expect(after.failure, isNotNull);
      expect(after.failure!.message, contains('No active workspace'));
    });
  });

  group('TranslationSettingsStore server-switch', () {
    test('store resets to initial on server switch', () async {
      const settingsA = TranslationSettings(
        preferredLanguage: 'ja',
        mode: TranslationMode.auto,
      );
      const settingsB = TranslationSettings(
        preferredLanguage: 'ko',
        mode: TranslationMode.manual,
      );

      const serverA = ServerScopeId('srv-a');
      const serverB = ServerScopeId('srv-b');

      final serverOverride = StateProvider<ServerScopeId?>(
        (ref) => serverA,
      );

      final fakeRepo = _SwitchableTranslationRepository({
        'srv-a': settingsA,
        'srv-b': settingsB,
      });

      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWith(
            (ref) => ref.watch(serverOverride),
          ),
          translationRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // Keep the provider alive so we can observe server-switch rebuild.
      final sub = container.listen(
        translationSettingsStoreProvider,
        (_, __) {},
      );

      // Load server A settings.
      await container.read(translationSettingsStoreProvider.notifier).load();
      expect(
        container
            .read(translationSettingsStoreProvider)
            .settings
            .preferredLanguage,
        'ja',
      );

      // Switch to server B — store should rebuild and reset to initial.
      container.read(serverOverride.notifier).state = serverB;

      final afterSwitch = container.read(translationSettingsStoreProvider);
      expect(afterSwitch.status, TranslationSettingsStatus.initial);

      // Load server B settings.
      await container.read(translationSettingsStoreProvider.notifier).load();
      expect(
        container
            .read(translationSettingsStoreProvider)
            .settings
            .preferredLanguage,
        'ko',
      );

      sub.close();
    });
  });
}

class _FakeTranslationRepository implements TranslationRepository {
  _FakeTranslationRepository({
    this.settings = const TranslationSettings(),
    this.failOnGet = false,
    this.failOnUpdate = false,
  });

  TranslationSettings settings;
  final bool failOnGet;
  final bool failOnUpdate;

  @override
  Future<TranslationSettings> getSettings(ServerScopeId serverId) async {
    if (failOnGet) throw const ServerFailure(message: 'API error');
    return settings;
  }

  @override
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings newSettings,
  ) async {
    if (failOnUpdate) throw const ServerFailure(message: 'API error');
    settings = newSettings;
    return settings;
  }

  @override
  Future<List<TranslationResult>> translateBatch(
    ServerScopeId serverId, {
    required List<String> messageIds,
    required String targetLanguage,
  }) async {
    return const [];
  }
}

/// Fake repository that returns different settings per server ID.
class _SwitchableTranslationRepository implements TranslationRepository {
  _SwitchableTranslationRepository(this._settingsPerServer);

  final Map<String, TranslationSettings> _settingsPerServer;

  @override
  Future<TranslationSettings> getSettings(ServerScopeId serverId) async {
    return _settingsPerServer[serverId.value] ?? const TranslationSettings();
  }

  @override
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings newSettings,
  ) async {
    _settingsPerServer[serverId.value] = newSettings;
    return newSettings;
  }

  @override
  Future<List<TranslationResult>> translateBatch(
    ServerScopeId serverId, {
    required List<String> messageIds,
    required String targetLanguage,
  }) async {
    return const [];
  }
}
