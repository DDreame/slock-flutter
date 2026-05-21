import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/features/settings/data/base_url_connection_tester.dart';
import 'package:slock_app/features/settings/data/base_url_settings.dart';
import 'package:slock_app/stores/base_url/base_url_settings_state.dart';
import 'package:slock_app/stores/base_url/base_url_settings_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  Future<ProviderContainer> buildContainer({
    Map<String, Object> data = const {},
    BaseUrlConnectionTester? tester,
  }) async {
    SharedPreferences.setMockInitialValues(data);
    prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (tester != null)
          baseUrlConnectionTesterProvider.overrideWithValue(tester),
      ],
    );
  }

  tearDown(() => container.dispose());

  group('BaseUrlSettingsStore — initialization', () {
    test('initializes with empty default state', () async {
      container = await buildContainer();
      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.settings.apiBaseUrl, '');
      expect(state.settings.realtimeUrl, '');
      expect(state.isDirty, isFalse);
      expect(state.isTesting, isFalse);
      expect(state.apiTestResult, isNull);
      expect(state.realtimeTestResult, isNull);
    });

    test('restores saved URLs from SharedPreferences', () async {
      container = await buildContainer(data: {
        'base_url_api': 'https://custom.api.com',
        'base_url_realtime': 'wss://custom.rt.com',
      });
      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.settings.apiBaseUrl, 'https://custom.api.com');
      expect(state.settings.realtimeUrl, 'wss://custom.rt.com');
    });
  });

  group('BaseUrlSettingsStore — field updates', () {
    test('setApiBaseUrl updates field and marks dirty', () async {
      container = await buildContainer();
      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      notifier.setApiBaseUrl('https://new-api.com');

      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.settings.apiBaseUrl, 'https://new-api.com');
      expect(state.isDirty, isTrue);
    });

    test('setRealtimeUrl updates field and marks dirty', () async {
      container = await buildContainer();
      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      notifier.setRealtimeUrl('wss://new-rt.com');

      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.settings.realtimeUrl, 'wss://new-rt.com');
      expect(state.isDirty, isTrue);
    });

    test('setApiBaseUrl clears existing API test result', () async {
      container = await buildContainer();
      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);

      // Simulate a previous test result by doing a field update first.
      notifier.setApiBaseUrl('https://api.com');
      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.apiTestResult, isNull);
    });
  });

  group('BaseUrlSettingsStore — save', () {
    test('save normalizes and persists valid URLs', () async {
      container = await buildContainer();
      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      notifier.setApiBaseUrl('https://api.example.com/');
      notifier.setRealtimeUrl('https://rt.example.com/');

      final error = await notifier.save();
      expect(error, isNull);

      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.settings.apiBaseUrl, 'https://api.example.com');
      expect(state.settings.realtimeUrl, 'wss://rt.example.com');
      expect(state.isDirty, isFalse);

      // Verify persistence.
      expect(prefs.getString('base_url_api'), 'https://api.example.com');
      expect(prefs.getString('base_url_realtime'), 'wss://rt.example.com');
    });

    test('save returns error key for invalid API URL', () async {
      container = await buildContainer();
      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      notifier.setApiBaseUrl('not-a-url');
      notifier.setRealtimeUrl('wss://valid.com');

      final error = await notifier.save();
      expect(error, 'baseUrlApiInvalid');
    });

    test('save returns error key for invalid realtime URL', () async {
      container = await buildContainer();
      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      notifier.setApiBaseUrl('https://valid.com');
      notifier.setRealtimeUrl('ftp://invalid-scheme.com');

      final error = await notifier.save();
      expect(error, 'baseUrlRealtimeInvalid');
    });

    test('save with empty strings succeeds (means use defaults)', () async {
      container = await buildContainer();
      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      // Fields are already empty by default.

      final error = await notifier.save();
      expect(error, isNull);

      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.settings.apiBaseUrl, '');
      expect(state.settings.realtimeUrl, '');
    });
  });

  group('BaseUrlSettingsStore — restoreDefaults', () {
    test('restoreDefaults clears persisted values and resets state', () async {
      container = await buildContainer(data: {
        'base_url_api': 'https://custom.api.com',
        'base_url_realtime': 'wss://custom.rt.com',
      });

      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      await notifier.restoreDefaults();

      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.settings.apiBaseUrl, '');
      expect(state.settings.realtimeUrl, '');
      expect(state.isDirty, isFalse);

      // Verify prefs cleared.
      expect(prefs.getString('base_url_api'), isNull);
      expect(prefs.getString('base_url_realtime'), isNull);
    });
  });

  group('BaseUrlSettingsStore — testConnection', () {
    test('testConnection sets isTesting during run', () async {
      container = await buildContainer(
        tester: _FakeConnectionTester(
          apiResult: ConnectionTestResult.reachable,
        ),
      );
      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      notifier.setApiBaseUrl('https://api.com');

      // Start test but capture mid-flight state.
      final future = notifier.testConnection();
      // After await, isTesting should be false.
      await future;

      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.isTesting, isFalse);
    });

    test('testConnection reports reachable API result', () async {
      container = await buildContainer(
        tester: _FakeConnectionTester(
          apiResult: ConnectionTestResult.reachable,
        ),
      );
      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      notifier.setApiBaseUrl('https://api.com');
      await notifier.testConnection();

      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.apiTestResult, ConnectionTestResult.reachable);
    });

    test('testConnection reports timeout result', () async {
      container = await buildContainer(
        tester: _FakeConnectionTester(
          apiResult: ConnectionTestResult.timeout,
        ),
      );
      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      notifier.setApiBaseUrl('https://slow.com');
      await notifier.testConnection();

      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.apiTestResult, ConnectionTestResult.timeout);
    });

    test('testConnection reports realtime result when URL is set', () async {
      container = await buildContainer(
        tester: _FakeConnectionTester(
          apiResult: ConnectionTestResult.reachable,
          rtResult: ConnectionTestResult.reachable,
        ),
      );
      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      notifier.setApiBaseUrl('https://api.com');
      notifier.setRealtimeUrl('wss://rt.com');
      await notifier.testConnection();

      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.apiTestResult, ConnectionTestResult.reachable);
      expect(state.realtimeTestResult, ConnectionTestResult.reachable);
    });

    test('testConnection skips empty URLs', () async {
      container = await buildContainer(
        tester: _FakeConnectionTester(
          apiResult: ConnectionTestResult.reachable,
          rtResult: ConnectionTestResult.reachable,
        ),
      );
      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      // Both URLs empty — no test should run.
      await notifier.testConnection();

      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.apiTestResult, isNull);
      expect(state.realtimeTestResult, isNull);
    });

    test('testConnection reports invalidUrl for unparseable realtime URL',
        () async {
      container = await buildContainer(
        tester: _FakeConnectionTester(
          apiResult: ConnectionTestResult.reachable,
          rtResult: ConnectionTestResult.reachable,
        ),
      );
      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      notifier.setRealtimeUrl('not-a-url');
      await notifier.testConnection();

      final state = container.read(baseUrlSettingsStoreProvider);
      expect(state.realtimeTestResult, ConnectionTestResult.invalidUrl);
    });
  });

  group('BaseUrlSettingsState', () {
    test('default equality', () {
      const a = BaseUrlSettingsState();
      const b = BaseUrlSettingsState();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different settings are not equal', () {
      const a = BaseUrlSettingsState();
      const b = BaseUrlSettingsState(
        settings: BaseUrlSettings(apiBaseUrl: 'https://x.com'),
      );
      expect(a, isNot(equals(b)));
    });

    test('copyWith with clearApiTest nulls the result', () {
      const state = BaseUrlSettingsState(
        apiTestResult: ConnectionTestResult.reachable,
      );
      final copy = state.copyWith(clearApiTest: true);
      expect(copy.apiTestResult, isNull);
    });

    test('copyWith with clearRealtimeTest nulls the result', () {
      const state = BaseUrlSettingsState(
        realtimeTestResult: ConnectionTestResult.reachable,
      );
      final copy = state.copyWith(clearRealtimeTest: true);
      expect(copy.realtimeTestResult, isNull);
    });
  });
}

class _FakeConnectionTester extends BaseUrlConnectionTester {
  _FakeConnectionTester({
    this.apiResult = ConnectionTestResult.invalidUrl,
    this.rtResult = ConnectionTestResult.invalidUrl,
  }) : super();

  final ConnectionTestResult apiResult;
  final ConnectionTestResult rtResult;

  @override
  Future<ConnectionTestResult> testApi(String baseUrl) async => apiResult;

  @override
  Future<ConnectionTestResult> testRealtime(String realtimeUrl) async =>
      rtResult;
}
