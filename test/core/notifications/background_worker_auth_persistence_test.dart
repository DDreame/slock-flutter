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
//                     returns populated BackgroundAuthProvider with
//                     matching fields
// INV-SEC-LOAD-2:    load() returns null tokens when nothing stored,
//                     realtimeUrl has fallback value
// INV-SEC-KEYS-1:    Background worker storage keys are distinct from
//                     session storage keys (no collision)
//
// Phase A: All tests skip:true — background worker still uses
// SharedPreferences, no SecureStorage integration yet.
//
// Phase B will:
// - Add SecureStorage parameter to BackgroundWorkerAuthPersistence
//   constructor (matching _TestableBackgroundWorkerAuthPersistence API)
// - Tests: swap _TestableBackgroundWorkerAuthPersistence → real class,
//   un-skip — no assertion rewrite needed
// ---------------------------------------------------------------------------
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/background_notification_entrypoint.dart';
import 'package:slock_app/core/notifications/background_notification_worker.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/session_storage_keys.dart';

void main() {
  // -----------------------------------------------------------------------
  // INV-SEC-PERSIST-1: persist() writes all 4 credentials to SecureStorage.
  //
  // Setup: Create a FakeSecureStorage, construct a
  // _TestableBackgroundWorkerAuthPersistence with it, call persist(),
  // verify all 4 keys are written.
  //
  // skip:true — persist() still uses SharedPreferences, no injection.
  // Phase B: Replace _TestableBackgroundWorkerAuthPersistence with
  // BackgroundWorkerAuthPersistence — same constructor + method API.
  // -----------------------------------------------------------------------
  test(
    'persist() writes credentials to SecureStorage '
    '(INV-SEC-PERSIST-1)',
    skip: true,
    () async {
      final secureStorage = _FakeSecureStorage();

      // Phase B: Replace with
      // final persistence = BackgroundWorkerAuthPersistence(secureStorage);
      final persistence =
          _TestableBackgroundWorkerAuthPersistence(secureStorage);

      await persistence.persist(
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
  // Setup: Pre-populate via persist(), call clear(), verify all 4 keys
  // are removed.
  //
  // skip:true — clear() still uses SharedPreferences, no injection.
  // Phase B: Replace _TestableBackgroundWorkerAuthPersistence with
  // BackgroundWorkerAuthPersistence — same constructor + method API.
  // -----------------------------------------------------------------------
  test(
    'clear() removes all credentials from SecureStorage '
    '(INV-SEC-PERSIST-2)',
    skip: true,
    () async {
      final secureStorage = _FakeSecureStorage();

      // Phase B: Replace with
      // final persistence = BackgroundWorkerAuthPersistence(secureStorage);
      final persistence =
          _TestableBackgroundWorkerAuthPersistence(secureStorage);

      // Pre-populate via the persist contract.
      await persistence.persist(
        token: 'jwt-token-123',
        userId: 'user-abc',
        serverId: 'server-xyz',
        realtimeUrl: 'wss://realtime.example.com',
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
    },
  );

  // -----------------------------------------------------------------------
  // INV-SEC-LOAD-1: load() reads credentials from SecureStorage and
  // returns a populated BackgroundAuthProvider with matching fields.
  //
  // Setup: Pre-populate via persist(), call load(), verify the returned
  // auth object has all 4 matching fields.
  //
  // skip:true — load() still reads from SharedPreferences.
  // Phase B: Replace _TestableBackgroundWorkerAuthPersistence with
  // BackgroundWorkerAuthPersistence — same constructor + method API.
  // -----------------------------------------------------------------------
  test(
    'load() reads credentials from SecureStorage and returns '
    'populated auth object (INV-SEC-LOAD-1)',
    skip: true,
    () async {
      final secureStorage = _FakeSecureStorage();

      // Phase B: Replace with
      // final persistence = BackgroundWorkerAuthPersistence(secureStorage);
      final persistence =
          _TestableBackgroundWorkerAuthPersistence(secureStorage);

      // Pre-populate SecureStorage via persist contract.
      await persistence.persist(
        token: 'jwt-token-123',
        userId: 'user-abc',
        serverId: 'server-xyz',
        realtimeUrl: 'wss://realtime.example.com',
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
    },
  );

  // -----------------------------------------------------------------------
  // INV-SEC-LOAD-2: load() returns null tokens when nothing is stored.
  //
  // Setup: Empty FakeSecureStorage, call load(), verify token/userId/
  // serverId are null and realtimeUrl has fallback.
  //
  // skip:true — load() still reads from SharedPreferences.
  // Phase B: Replace _TestableBackgroundWorkerAuthPersistence with
  // BackgroundWorkerAuthPersistence — same constructor + method API.
  // -----------------------------------------------------------------------
  test(
    'load() returns null tokens when nothing stored '
    '(INV-SEC-LOAD-2)',
    skip: true,
    () async {
      final secureStorage = _FakeSecureStorage();

      // Phase B: Replace with
      // final persistence = BackgroundWorkerAuthPersistence(secureStorage);
      final persistence =
          _TestableBackgroundWorkerAuthPersistence(secureStorage);

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
// Test-local class mirroring the Phase B API of
// BackgroundWorkerAuthPersistence with SecureStorage injection.
//
// Phase B: Replace _TestableBackgroundWorkerAuthPersistence with the real
// BackgroundWorkerAuthPersistence — same constructor accepting
// SecureStorage, same persist()/clear()/load() method signatures.
//
// The class has a single constructor taking SecureStorage, and instance
// methods persist/clear/load that delegate to it. Phase B adds the same
// constructor + methods to the real class, and tests swap the class name.
// ---------------------------------------------------------------------------

/// Test-local stand-in for the Phase B [BackgroundWorkerAuthPersistence]
/// API. Constructor takes [SecureStorage]; methods mirror the real class
/// signatures so Phase B only swaps the class name and un-skips.
class _TestableBackgroundWorkerAuthPersistence {
  _TestableBackgroundWorkerAuthPersistence(this._storage);

  final SecureStorage _storage;

  /// Persist auth credentials to [SecureStorage].
  /// Phase B: Same signature on real BackgroundWorkerAuthPersistence.
  Future<void> persist({
    required String token,
    required String userId,
    required String serverId,
    required String realtimeUrl,
  }) async {
    await Future.wait([
      _storage.write(key: backgroundWorkerTokenKey, value: token),
      _storage.write(key: backgroundWorkerUserIdKey, value: userId),
      _storage.write(key: backgroundWorkerServerIdKey, value: serverId),
      _storage.write(key: backgroundWorkerRealtimeUrlKey, value: realtimeUrl),
    ]);
  }

  /// Clear persisted auth from [SecureStorage].
  /// Phase B: Same signature on real BackgroundWorkerAuthPersistence.
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: backgroundWorkerTokenKey),
      _storage.delete(key: backgroundWorkerUserIdKey),
      _storage.delete(key: backgroundWorkerServerIdKey),
      _storage.delete(key: backgroundWorkerRealtimeUrlKey),
    ]);
  }

  /// Load auth credentials from [SecureStorage] and return a
  /// [BackgroundAuthProvider] with matching fields.
  /// Phase B: Same signature on real BackgroundWorkerAuthPersistence.
  Future<BackgroundAuthProvider> load() async {
    return _SecureStorageAuthProvider(
      token: await _storage.read(key: backgroundWorkerTokenKey),
      userId: await _storage.read(key: backgroundWorkerUserIdKey),
      serverId: await _storage.read(key: backgroundWorkerServerIdKey),
      realtimeUrl: await _storage.read(key: backgroundWorkerRealtimeUrlKey) ??
          'wss://realtime.slock.invalid',
    );
  }
}

// ---------------------------------------------------------------------------
// Test-local fakes
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

/// Test-local [BackgroundAuthProvider] returned by
/// [_TestableBackgroundWorkerAuthPersistence.load].
/// Mirrors `_SharedPrefsAuthProvider` from background_notification_entrypoint
/// — same fields, same fallback logic for [realtimeUrl].
class _SecureStorageAuthProvider implements BackgroundAuthProvider {
  const _SecureStorageAuthProvider({
    required this.token,
    required this.userId,
    required this.serverId,
    required this.realtimeUrl,
  });

  @override
  final String? token;

  @override
  final String? userId;

  @override
  final String? serverId;

  @override
  final String realtimeUrl;
}
