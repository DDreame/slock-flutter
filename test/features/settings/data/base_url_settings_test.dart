import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/features/settings/data/base_url_settings.dart';

void main() {
  group('BaseUrlSettings', () {
    test('default constructor has empty strings', () {
      const settings = BaseUrlSettings();
      expect(settings.apiBaseUrl, '');
      expect(settings.realtimeUrl, '');
    });

    test('hasApiOverride returns false for empty', () {
      const settings = BaseUrlSettings();
      expect(settings.hasApiOverride, false);
    });

    test('hasApiOverride returns true for non-empty', () {
      const settings = BaseUrlSettings(
        apiBaseUrl: 'https://api.example.com',
      );
      expect(settings.hasApiOverride, true);
    });

    test('hasRealtimeOverride returns false for empty', () {
      const settings = BaseUrlSettings();
      expect(settings.hasRealtimeOverride, false);
    });

    test('hasRealtimeOverride returns true for non-empty', () {
      const settings = BaseUrlSettings(
        realtimeUrl: 'wss://realtime.example.com',
      );
      expect(settings.hasRealtimeOverride, true);
    });

    test('copyWith creates modified copy', () {
      const original = BaseUrlSettings(
        apiBaseUrl: 'https://old.com',
        realtimeUrl: 'wss://old.com',
      );
      final copy = original.copyWith(
        apiBaseUrl: 'https://new.com',
      );
      expect(copy.apiBaseUrl, 'https://new.com');
      expect(copy.realtimeUrl, 'wss://old.com');
    });

    test('equality', () {
      const a = BaseUrlSettings(
        apiBaseUrl: 'https://a.com',
        realtimeUrl: 'wss://a.com',
      );
      const b = BaseUrlSettings(
        apiBaseUrl: 'https://a.com',
        realtimeUrl: 'wss://a.com',
      );
      const c = BaseUrlSettings(
        apiBaseUrl: 'https://b.com',
        realtimeUrl: 'wss://a.com',
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('SharedPrefsBaseUrlRepository', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('load returns empty settings when nothing stored', () {
      final repo = SharedPrefsBaseUrlRepository(prefs: prefs);
      final settings = repo.load();
      expect(settings.apiBaseUrl, '');
      expect(settings.realtimeUrl, '');
    });

    test('save persists and load reads back', () async {
      final repo = SharedPrefsBaseUrlRepository(prefs: prefs);
      const settings = BaseUrlSettings(
        apiBaseUrl: 'https://api.example.com',
        realtimeUrl: 'wss://rt.example.com',
      );

      await repo.save(settings);
      final loaded = repo.load();

      expect(loaded.apiBaseUrl, 'https://api.example.com');
      expect(loaded.realtimeUrl, 'wss://rt.example.com');
    });

    test('save removes keys for empty values', () async {
      final repo = SharedPrefsBaseUrlRepository(prefs: prefs);

      // First save non-empty
      await repo.save(
        const BaseUrlSettings(
          apiBaseUrl: 'https://api.example.com',
          realtimeUrl: 'wss://rt.example.com',
        ),
      );

      // Then save empty
      await repo.save(const BaseUrlSettings());
      final loaded = repo.load();

      expect(loaded.apiBaseUrl, '');
      expect(loaded.realtimeUrl, '');
    });

    test('clear removes all keys', () async {
      final repo = SharedPrefsBaseUrlRepository(prefs: prefs);
      await repo.save(
        const BaseUrlSettings(
          apiBaseUrl: 'https://api.example.com',
          realtimeUrl: 'wss://rt.example.com',
        ),
      );

      await repo.clear();
      final loaded = repo.load();

      expect(loaded.apiBaseUrl, '');
      expect(loaded.realtimeUrl, '');
    });
  });
}
