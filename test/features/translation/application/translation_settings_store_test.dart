import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
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
    if (failOnGet) throw Exception('API error');
    return settings;
  }

  @override
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings newSettings,
  ) async {
    if (failOnUpdate) throw Exception('API error');
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
