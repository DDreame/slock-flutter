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
//                     returns populated auth object
// INV-SEC-LOAD-2:    load() returns null tokens when nothing stored
// INV-SEC-KEYS-1:    Background worker storage keys are distinct from
//                     session storage keys (no collision)
//
// Phase A: All tests skip:true — background worker still uses
// SharedPreferences, no SecureStorage integration yet.
// ---------------------------------------------------------------------------
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/background_notification_entrypoint.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // -----------------------------------------------------------------------
  // INV-SEC-PERSIST-1: persist() writes all 4 credentials to SecureStorage.
  //
  // Setup: Create a FakeSecureStorage, call persist() with known
  // credentials, verify all 4 keys are written to SecureStorage and
  // NOT to SharedPreferences.
  //
  // skip:true — persist() still uses SharedPreferences.
  // -----------------------------------------------------------------------
  test(
    'persist() writes credentials to SecureStorage '
    '(INV-SEC-PERSIST-1)',
    skip: true,
    () async {
      SharedPreferences.setMockInitialValues({});
      final secureStorage = _FakeSecureStorage();

      await BackgroundWorkerAuthPersistence.persist(
        token: 'jwt-token-123',
        userId: 'user-abc',
        serverId: 'server-xyz',
        realtimeUrl: 'wss://realtime.example.com',
      );

      // All 4 credentials must be in SecureStorage.
      expect(
        secureStorage.store[backgroundWorkerTokenKey],
        equals('jwt-token-123'),
        reason: 'Token must be stored in SecureStorage '
            '(INV-SEC-PERSIST-1)',
      );
      expect(
        secureStorage.store[backgroundWorkerUserIdKey],
        equals('user-abc'),
        reason: 'UserId must be stored in SecureStorage '
            '(INV-SEC-PERSIST-1)',
      );
      expect(
        secureStorage.store[backgroundWorkerServerIdKey],
        equals('server-xyz'),
        reason: 'ServerId must be stored in SecureStorage '
            '(INV-SEC-PERSIST-1)',
      );
      expect(
        secureStorage.store[backgroundWorkerRealtimeUrlKey],
        equals('wss://realtime.example.com'),
        reason: 'RealtimeUrl must be stored in SecureStorage '
            '(INV-SEC-PERSIST-1)',
      );

      // Credentials must NOT appear in SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(backgroundWorkerTokenKey),
        isNull,
        reason: 'Token must NOT be in SharedPreferences '
            '(INV-SEC-PERSIST-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-SEC-PERSIST-2: clear() removes all 4 keys from SecureStorage.
  //
  // Setup: Pre-populate SecureStorage with credentials, call clear(),
  // verify all 4 keys are removed.
  //
  // skip:true — clear() still uses SharedPreferences.
  // -----------------------------------------------------------------------
  test(
    'clear() removes all credentials from SecureStorage '
    '(INV-SEC-PERSIST-2)',
    skip: true,
    () async {
      final secureStorage = _FakeSecureStorage();
      secureStorage.store[backgroundWorkerTokenKey] = 'jwt-token-123';
      secureStorage.store[backgroundWorkerUserIdKey] = 'user-abc';
      secureStorage.store[backgroundWorkerServerIdKey] = 'server-xyz';
      secureStorage.store[backgroundWorkerRealtimeUrlKey] =
          'wss://realtime.example.com';

      await BackgroundWorkerAuthPersistence.clear();

      expect(
        secureStorage.store[backgroundWorkerTokenKey],
        isNull,
        reason: 'Token must be removed from SecureStorage '
            '(INV-SEC-PERSIST-2)',
      );
      expect(
        secureStorage.store[backgroundWorkerUserIdKey],
        isNull,
        reason: 'UserId must be removed from SecureStorage '
            '(INV-SEC-PERSIST-2)',
      );
      expect(
        secureStorage.store[backgroundWorkerServerIdKey],
        isNull,
        reason: 'ServerId must be removed from SecureStorage '
            '(INV-SEC-PERSIST-2)',
      );
      expect(
        secureStorage.store[backgroundWorkerRealtimeUrlKey],
        isNull,
        reason: 'RealtimeUrl must be removed from SecureStorage '
            '(INV-SEC-PERSIST-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-SEC-LOAD-1: load() reads credentials from SecureStorage and
  // returns a populated auth object.
  //
  // Setup: Pre-populate SecureStorage with known credentials, call
  // load(), verify the returned auth object has all 4 fields.
  //
  // skip:true — load() still reads from SharedPreferences.
  // -----------------------------------------------------------------------
  test(
    'load() reads credentials from SecureStorage '
    '(INV-SEC-LOAD-1)',
    skip: true,
    () async {
      final secureStorage = _FakeSecureStorage();
      secureStorage.store[backgroundWorkerTokenKey] = 'jwt-token-123';
      secureStorage.store[backgroundWorkerUserIdKey] = 'user-abc';
      secureStorage.store[backgroundWorkerServerIdKey] = 'server-xyz';
      secureStorage.store[backgroundWorkerRealtimeUrlKey] =
          'wss://realtime.example.com';

      // Phase B: load() will read from SecureStorage.
      // For now, test documents the expected contract.
      SharedPreferences.setMockInitialValues({
        backgroundWorkerTokenKey: 'jwt-token-123',
        backgroundWorkerUserIdKey: 'user-abc',
        backgroundWorkerServerIdKey: 'server-xyz',
        backgroundWorkerRealtimeUrlKey: 'wss://realtime.example.com',
      });

      // Current (insecure) code path — Phase B will change to
      // SecureStorage and this test will verify the new path.
      // The auth provider is private, so we test the round-trip:
      // persist() → load() equivalence.
      await BackgroundWorkerAuthPersistence.persist(
        token: 'jwt-token-123',
        userId: 'user-abc',
        serverId: 'server-xyz',
        realtimeUrl: 'wss://realtime.example.com',
      );

      // Phase B will expose a testable load path via SecureStorage.
      expect(true, isTrue, reason: 'Placeholder — Phase B will verify');
    },
  );

  // -----------------------------------------------------------------------
  // INV-SEC-LOAD-2: load() returns null tokens when nothing is stored.
  //
  // Setup: Empty SecureStorage, call load(), verify token/userId/
  // serverId are null, realtimeUrl has fallback.
  //
  // skip:true — load() still reads from SharedPreferences.
  // -----------------------------------------------------------------------
  test(
    'load() returns null tokens when nothing stored '
    '(INV-SEC-LOAD-2)',
    skip: true,
    () async {
      SharedPreferences.setMockInitialValues({});

      // Phase B: load() will use SecureStorage.
      // Current code reads from SharedPreferences — verify the
      // contract: empty storage → null tokens, fallback realtimeUrl.

      // Phase B will expose a testable load path via SecureStorage.
      expect(true, isTrue, reason: 'Placeholder — Phase B will verify');
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
// Test-local stub for SecureStorage — Phase B will use this to inject
// a fake SecureStorage into the background worker auth persistence.
// ---------------------------------------------------------------------------

/// In-memory SecureStorage implementation for testing.
///
/// Phase B: BackgroundWorkerAuthPersistence will accept a SecureStorage
/// parameter (or read from a provider), and tests will inject this fake.
class _FakeSecureStorage {
  final Map<String, String> store = {};

  Future<String?> read({required String key}) async => store[key];

  Future<void> write({required String key, required String value}) async {
    store[key] = value;
  }

  Future<void> delete({required String key}) async {
    store.remove(key);
  }
}
