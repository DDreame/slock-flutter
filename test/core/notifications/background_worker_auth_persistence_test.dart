// ---------------------------------------------------------------------------
// #545: Background Worker Token 安全存储迁移
//
// Problem: BackgroundWorkerAuthPersistence stored auth JWT, userId,
// serverId, realtimeUrl in plain SharedPreferences. Main session
// correctly uses FlutterSecureStorage via SecureStorage abstraction.
// Background worker bypassed it — rooted device / backup extraction
// exposed credentials.
//
// Phase B: BackgroundWorkerAuthPersistence now accepts SecureStorage
// via constructor, all SharedPreferences usage replaced.
//
// Invariants verified:
// INV-SEC-PERSIST-1: persist() writes token/userId/serverId/realtimeUrl
//                     to SecureStorage (not SharedPreferences)
// INV-SEC-PERSIST-2: clear() removes all 4 keys from SecureStorage
// INV-SEC-LOAD-1:    load() reads credentials from SecureStorage and
//                     returns populated BackgroundAuthProvider with
//                     matching fields
// INV-SEC-LOAD-2:    load() returns null tokens when nothing stored,
//                     realtimeUrl has fallback value
// INV-SEC-KEYS-1:    Background worker storage keys are distinct from
//                     session storage keys (no collision)
// ---------------------------------------------------------------------------
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/background_notification_entrypoint.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';

void main() {
  // -----------------------------------------------------------------------
  // INV-SEC-PERSIST-1: persist() writes all 4 credentials to SecureStorage.
  // -----------------------------------------------------------------------
  test(
    'persist() writes credentials to SecureStorage '
    '(INV-SEC-PERSIST-1)',
    () async {
      final secureStorage = _FakeSecureStorage();
      final persistence = BackgroundWorkerAuthPersistence(secureStorage);

      await persistence.persist(
        token: 'jwt-token-123',
        userId: 'user-abc',
        serverId: 'server-xyz',
        realtimeUrl: 'wss://realtime.example.com',
        apiBaseUrl: 'https://api.example.com',
      );

      // All 4 credentials must be in SecureStorage.
      expect(
        await secureStorage.read(key: backgroundWorkerTokenKey),
        equals('jwt-token-123'),
        reason: 'Token must be stored in SecureStorage '
            '(INV-SEC-PERSIST-1)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerUserIdKey),
        equals('user-abc'),
        reason: 'UserId must be stored in SecureStorage '
            '(INV-SEC-PERSIST-1)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerServerIdKey),
        equals('server-xyz'),
        reason: 'ServerId must be stored in SecureStorage '
            '(INV-SEC-PERSIST-1)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerRealtimeUrlKey),
        equals('wss://realtime.example.com'),
        reason: 'RealtimeUrl must be stored in SecureStorage '
            '(INV-SEC-PERSIST-1)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerApiBaseUrlKey),
        equals('https://api.example.com'),
        reason: 'ApiBaseUrl must be stored in SecureStorage '
            '(INV-SEC-PERSIST-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-SEC-PERSIST-2: clear() removes all 4 keys from SecureStorage.
  // -----------------------------------------------------------------------
  test(
    'clear() removes all credentials from SecureStorage '
    '(INV-SEC-PERSIST-2)',
    () async {
      final secureStorage = _FakeSecureStorage();
      final persistence = BackgroundWorkerAuthPersistence(secureStorage);

      // Pre-populate via the persist contract.
      await persistence.persist(
        token: 'jwt-token-123',
        userId: 'user-abc',
        serverId: 'server-xyz',
        realtimeUrl: 'wss://realtime.example.com',
        apiBaseUrl: 'https://api.example.com',
      );

      await persistence.clear();

      // All 4 keys must be removed.
      expect(
        await secureStorage.read(key: backgroundWorkerTokenKey),
        isNull,
        reason: 'Token must be removed from SecureStorage '
            '(INV-SEC-PERSIST-2)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerUserIdKey),
        isNull,
        reason: 'UserId must be removed from SecureStorage '
            '(INV-SEC-PERSIST-2)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerServerIdKey),
        isNull,
        reason: 'ServerId must be removed from SecureStorage '
            '(INV-SEC-PERSIST-2)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerRealtimeUrlKey),
        isNull,
        reason: 'RealtimeUrl must be removed from SecureStorage '
            '(INV-SEC-PERSIST-2)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerApiBaseUrlKey),
        isNull,
        reason: 'ApiBaseUrl must be removed from SecureStorage '
            '(INV-SEC-PERSIST-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-SEC-LOAD-1: load() reads credentials from SecureStorage and
  // returns a populated BackgroundAuthProvider with matching fields.
  // -----------------------------------------------------------------------
  test(
    'load() reads credentials from SecureStorage and returns '
    'populated auth object (INV-SEC-LOAD-1)',
    () async {
      final secureStorage = _FakeSecureStorage();
      final persistence = BackgroundWorkerAuthPersistence(secureStorage);

      // Pre-populate SecureStorage via persist contract.
      await persistence.persist(
        token: 'jwt-token-123',
        userId: 'user-abc',
        serverId: 'server-xyz',
        realtimeUrl: 'wss://realtime.example.com',
        apiBaseUrl: 'https://api.example.com',
      );

      // Load and assert the returned auth object fields.
      final auth = await persistence.load();

      expect(
        auth.token,
        equals('jwt-token-123'),
        reason: 'Auth token must match persisted value '
            '(INV-SEC-LOAD-1)',
      );
      expect(
        auth.userId,
        equals('user-abc'),
        reason: 'Auth userId must match persisted value '
            '(INV-SEC-LOAD-1)',
      );
      expect(
        auth.serverId,
        equals('server-xyz'),
        reason: 'Auth serverId must match persisted value '
            '(INV-SEC-LOAD-1)',
      );
      expect(
        auth.realtimeUrl,
        equals('wss://realtime.example.com'),
        reason: 'Auth realtimeUrl must match persisted value '
            '(INV-SEC-LOAD-1)',
      );
      expect(
        auth.apiBaseUrl,
        equals('https://api.example.com'),
        reason: 'Auth apiBaseUrl must match persisted value '
            '(INV-SEC-LOAD-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-SEC-LOAD-2: load() returns null tokens when nothing is stored.
  // -----------------------------------------------------------------------
  test(
    'load() returns null tokens when nothing stored '
    '(INV-SEC-LOAD-2)',
    () async {
      final secureStorage = _FakeSecureStorage();
      final persistence = BackgroundWorkerAuthPersistence(secureStorage);

      // Load from empty storage.
      final auth = await persistence.load();

      // Empty storage → null/fallback fields.
      expect(
        auth.token,
        isNull,
        reason: 'Auth token must be null when nothing stored '
            '(INV-SEC-LOAD-2)',
      );
      expect(
        auth.userId,
        isNull,
        reason: 'Auth userId must be null when nothing stored '
            '(INV-SEC-LOAD-2)',
      );
      expect(
        auth.serverId,
        isNull,
        reason: 'Auth serverId must be null when nothing stored '
            '(INV-SEC-LOAD-2)',
      );
      expect(
        auth.realtimeUrl,
        equals('wss://realtime.slock.invalid'),
        reason: 'Auth realtimeUrl must fall back to default when '
            'nothing stored (INV-SEC-LOAD-2)',
      );
      expect(
        auth.apiBaseUrl,
        equals('https://api.slock.invalid'),
        reason: 'Auth apiBaseUrl must fall back to default when '
            'nothing stored (INV-SEC-LOAD-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-SEC-KEYS-1: Background worker storage keys are distinct from
  // session storage keys — no collision between the two sets.
  // -----------------------------------------------------------------------
  test(
    'background worker keys do not collide with session keys '
    '(INV-SEC-KEYS-1)',
    () {
      final backgroundKeys = {
        backgroundWorkerTokenKey,
        backgroundWorkerUserIdKey,
        backgroundWorkerServerIdKey,
        backgroundWorkerRealtimeUrlKey,
        backgroundWorkerApiBaseUrlKey,
      };

      final sessionKeys = {
        SessionStorageKeys.token,
        SessionStorageKeys.refreshToken,
        SessionStorageKeys.userId,
        SessionStorageKeys.displayName,
      };

      final collision = backgroundKeys.intersection(sessionKeys);
      expect(
        collision,
        isEmpty,
        reason: 'Background worker and session storage keys must not '
            'collide (INV-SEC-KEYS-1)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Test-local fakes
// ---------------------------------------------------------------------------

/// In-memory [SecureStorage] implementation for testing.
class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> store = {};

  @override
  Future<String?> read({required String key}) async => store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    store.remove(key);
  }
}
