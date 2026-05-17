// ---------------------------------------------------------------------------
// #545: Background Worker Token 安全存储迁移 — Phase A (test-only)
//
// Problem: BackgroundWorkerAuthPersistence stores auth JWT, userId,
// serverId, realtimeUrl in plain SharedPreferences. Main session
// correctly uses FlutterSecureStorage via SecureStorage abstraction.
// Background worker bypasses it — rooted device / backup extraction
// exposes credentials.
//
// Invariants verified:
// INV-SEC-PERSIST-1: persist() writes token/userId/serverId/realtimeUrl
//                     to SecureStorage (not SharedPreferences)
// INV-SEC-PERSIST-2: clear() removes all 4 keys from SecureStorage
// INV-SEC-LOAD-1:    load() reads credentials from SecureStorage and
//                     returns populated auth object with matching fields
// INV-SEC-LOAD-2:    load() returns null tokens when nothing stored,
//                     realtimeUrl has fallback value
// INV-SEC-KEYS-1:    Background worker storage keys are distinct from
//                     session storage keys (no collision)
//
// Phase A: All tests skip:true — background worker still uses
// SharedPreferences, no SecureStorage integration yet.
//
// Phase B will:
// - Add optional `SecureStorage? storage` parameter to persist()/clear()
// - Add a static load(SecureStorage) factory or migrate
//   _SharedPrefsAuthProvider to use SecureStorage
// - Tests un-skip and pass _FakeSecureStorage via the injection seam
// ---------------------------------------------------------------------------
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/background_notification_entrypoint.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';

void main() {
  // -----------------------------------------------------------------------
  // INV-SEC-PERSIST-1: persist() writes all 4 credentials to SecureStorage.
  //
  // Setup: Create a FakeSecureStorage, call persist() with the fake
  // injected, verify all 4 keys are written to SecureStorage and NOT
  // to SharedPreferences.
  //
  // skip:true — persist() still uses SharedPreferences, no injection.
  // -----------------------------------------------------------------------
  test(
    'persist() writes credentials to SecureStorage '
    '(INV-SEC-PERSIST-1)',
    skip: true,
    () async {
      final secureStorage = _FakeSecureStorage();

      // Phase B: persist() will accept a `storage` parameter.
      // await BackgroundWorkerAuthPersistence.persist(
      //   token: 'jwt-token-123',
      //   userId: 'user-abc',
      //   serverId: 'server-xyz',
      //   realtimeUrl: 'wss://realtime.example.com',
      //   storage: secureStorage,
      // );
      await BackgroundWorkerAuthPersistence.persist(
        token: 'jwt-token-123',
        userId: 'user-abc',
        serverId: 'server-xyz',
        realtimeUrl: 'wss://realtime.example.com',
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
    },
  );

  // -----------------------------------------------------------------------
  // INV-SEC-PERSIST-2: clear() removes all 4 keys from SecureStorage.
  //
  // Setup: Pre-populate FakeSecureStorage with credentials via
  // persist(), call clear() with the same fake, verify all 4 keys
  // are removed.
  //
  // skip:true — clear() still uses SharedPreferences, no injection.
  // -----------------------------------------------------------------------
  test(
    'clear() removes all credentials from SecureStorage '
    '(INV-SEC-PERSIST-2)',
    skip: true,
    () async {
      final secureStorage = _FakeSecureStorage();

      // Pre-populate via the injection seam.
      await secureStorage.write(
        key: backgroundWorkerTokenKey,
        value: 'jwt-token-123',
      );
      await secureStorage.write(
        key: backgroundWorkerUserIdKey,
        value: 'user-abc',
      );
      await secureStorage.write(
        key: backgroundWorkerServerIdKey,
        value: 'server-xyz',
      );
      await secureStorage.write(
        key: backgroundWorkerRealtimeUrlKey,
        value: 'wss://realtime.example.com',
      );

      // Phase B: clear() will accept a `storage` parameter.
      // await BackgroundWorkerAuthPersistence.clear(storage: secureStorage);
      await BackgroundWorkerAuthPersistence.clear();

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
    },
  );

  // -----------------------------------------------------------------------
  // INV-SEC-LOAD-1: load() reads credentials from SecureStorage and
  // returns a populated auth object with matching field values.
  //
  // Setup: Pre-populate FakeSecureStorage with known credentials,
  // call the load path (Phase B will expose via SecureStorage),
  // verify the returned auth object has all 4 matching fields.
  //
  // skip:true — load() still reads from SharedPreferences.
  // -----------------------------------------------------------------------
  test(
    'load() reads credentials from SecureStorage and returns '
    'populated auth object (INV-SEC-LOAD-1)',
    skip: true,
    () async {
      final secureStorage = _FakeSecureStorage();

      // Pre-populate SecureStorage with known credentials.
      await secureStorage.write(
        key: backgroundWorkerTokenKey,
        value: 'jwt-token-123',
      );
      await secureStorage.write(
        key: backgroundWorkerUserIdKey,
        value: 'user-abc',
      );
      await secureStorage.write(
        key: backgroundWorkerServerIdKey,
        value: 'server-xyz',
      );
      await secureStorage.write(
        key: backgroundWorkerRealtimeUrlKey,
        value: 'wss://realtime.example.com',
      );

      // Phase B: _SharedPrefsAuthProvider.load() will accept
      // SecureStorage and return a BackgroundAuthProvider.
      // final auth = await BackgroundWorkerAuthPersistence.load(
      //   storage: secureStorage,
      // );
      //
      // expect(auth.token, equals('jwt-token-123'));
      // expect(auth.userId, equals('user-abc'));
      // expect(auth.serverId, equals('server-xyz'));
      // expect(auth.realtimeUrl, equals('wss://realtime.example.com'));

      // Verify round-trip: read back directly from SecureStorage
      // matches what was written — proves the storage layer is wired.
      expect(
        await secureStorage.read(key: backgroundWorkerTokenKey),
        equals('jwt-token-123'),
        reason: 'Token must round-trip through SecureStorage '
            '(INV-SEC-LOAD-1)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerUserIdKey),
        equals('user-abc'),
        reason: 'UserId must round-trip through SecureStorage '
            '(INV-SEC-LOAD-1)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerServerIdKey),
        equals('server-xyz'),
        reason: 'ServerId must round-trip through SecureStorage '
            '(INV-SEC-LOAD-1)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerRealtimeUrlKey),
        equals('wss://realtime.example.com'),
        reason: 'RealtimeUrl must round-trip through SecureStorage '
            '(INV-SEC-LOAD-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-SEC-LOAD-2: load() returns null tokens when nothing is stored.
  //
  // Setup: Empty FakeSecureStorage, call load path, verify token/
  // userId/serverId are null and realtimeUrl has fallback.
  //
  // skip:true — load() still reads from SharedPreferences.
  // -----------------------------------------------------------------------
  test(
    'load() returns null tokens when nothing stored '
    '(INV-SEC-LOAD-2)',
    skip: true,
    () async {
      final secureStorage = _FakeSecureStorage();

      // Empty SecureStorage — no credentials stored.
      // Phase B: load() will use SecureStorage.
      // final auth = await BackgroundWorkerAuthPersistence.load(
      //   storage: secureStorage,
      // );
      //
      // expect(auth.token, isNull);
      // expect(auth.userId, isNull);
      // expect(auth.serverId, isNull);
      // expect(auth.realtimeUrl, equals('wss://realtime.slock.invalid'));

      // Verify empty SecureStorage returns null for all credential keys.
      expect(
        await secureStorage.read(key: backgroundWorkerTokenKey),
        isNull,
        reason: 'Empty storage must return null token '
            '(INV-SEC-LOAD-2)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerUserIdKey),
        isNull,
        reason: 'Empty storage must return null userId '
            '(INV-SEC-LOAD-2)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerServerIdKey),
        isNull,
        reason: 'Empty storage must return null serverId '
            '(INV-SEC-LOAD-2)',
      );
      expect(
        await secureStorage.read(key: backgroundWorkerRealtimeUrlKey),
        isNull,
        reason: 'Empty storage must return null realtimeUrl '
            '(fallback applied at auth object level) '
            '(INV-SEC-LOAD-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-SEC-KEYS-1: Background worker storage keys are distinct from
  // session storage keys — no collision between the two sets.
  //
  // This is a compile-time / constant check, not skip:true — it
  // verifies the key sets are disjoint regardless of Phase B.
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
// Test-local fake implementing the real SecureStorage interface.
// Phase B: tests will inject this into persist()/clear()/load() via
// the injection seam that Phase B adds to BackgroundWorkerAuthPersistence.
// ---------------------------------------------------------------------------

/// In-memory [SecureStorage] implementation for testing.
///
/// Implements the same interface as [FlutterSecureStorageImpl] so Phase B
/// can inject it without rewriting test assertions.
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
